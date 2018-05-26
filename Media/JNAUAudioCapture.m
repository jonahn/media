//
//  JNAUAudioCapture.m
//  ShortVideo
//
//  Created by Jonathan on 2018/4/23.
//  Copyright © 2018年 JN. All rights reserved.
//

#import "JNAUAudioCapture.h"

#define JNAudioProcessingQueue "JN.AudioProcessingQueue"

@interface JNAUAudioCapture ()
{
    AudioComponentDescription _acDesc;
    AudioComponent _audioComponent;
}
@property (nonatomic, assign) double sampleRate;
@property (nonatomic, assign) AudioStreamBasicDescription streamDesc;
@property (nonatomic, assign) AudioComponentInstance audioComponentInstance;
@property (nonatomic, strong) dispatch_queue_t audioProcessingQueue;
@end

@implementation JNAUAudioCapture
- (instancetype)initWithSampleRate:(double)sampleRate
{
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;
        [self jn__setup];
    }
    return self;
}

- (instancetype)init
{
    self = [self initWithSampleRate:48000.0];
    if (self) {
        
    }
    return self;
}

- (dispatch_queue_t)audioProcessingQueue
{
    if(!_audioProcessingQueue){
        _audioProcessingQueue = dispatch_queue_create(JNAudioProcessingQueue, DISPATCH_QUEUE_SERIAL);
    }
    return _audioProcessingQueue;
}

- (void)jn__setup
{
    NSError *error = nil;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord  withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetooth  error:&error];
    [session setActive:YES error:nil];
    
    _streamDesc = [self getStreamBaseDesc];
    
    _acDesc.componentType = kAudioUnitType_Output;
    _acDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    _acDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    _acDesc.componentFlags = 0;
    _acDesc.componentFlagsMask = 0;
    
    _audioComponent = AudioComponentFindNext(NULL, &_acDesc);
    AudioComponentInstanceNew(_audioComponent, &_audioComponentInstance);
    
    UInt32 flagOne = 1;
    AudioUnitSetProperty(_audioComponentInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
    AudioUnitSetProperty(_audioComponentInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &_streamDesc, sizeof(_streamDesc));
    
    AURenderCallbackStruct micCallback;
    micCallback.inputProcRefCon = (__bridge void *)(self);
    micCallback.inputProc = jn__micCallBackFun;
    
    AudioUnitSetProperty(_audioComponentInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &micCallback, sizeof(micCallback));
}

OSStatus jn__micCallBackFun(void *inRefCon,
                            AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp,
                            UInt32 inBusNumber,
                            UInt32 inNumberFrames,
                            AudioBufferList *ioData)
{
    @autoreleasepool {
        JNAUAudioCapture *ref = (__bridge JNAUAudioCapture *)inRefCon;
        
        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 1;
        
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0] = buffer;
        
        AudioUnitRender(ref.audioComponentInstance,
                        ioActionFlags,
                        inTimeStamp,
                        inBusNumber,
                        inNumberFrames,
                        &bufferList);
        if (ref.audioProcessingBufferList) {
            ref.audioProcessingBufferList(bufferList, inNumberFrames);
        }
        if (ref.audioProcessingCallback) {
            [ref jn__toSampleBuffer:bufferList inNumberFrames:inNumberFrames];
        }
        return noErr;
    }
}

- (AudioStreamBasicDescription)getStreamBaseDesc
{
    AudioStreamBasicDescription desc =  {
        .mSampleRate = _sampleRate,
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        .mChannelsPerFrame = 1,
        .mFramesPerPacket = 1,
        .mBitsPerChannel = 16,
        .mBytesPerFrame = 2,
        .mBytesPerPacket = 2,
    };
    return desc;
}

- (void)jn__toSampleBuffer:(AudioBufferList)audioBufferList inNumberFrames:(UInt32)inNumberFrames
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.audioProcessingQueue, ^{
        AudioStreamBasicDescription asbd = [weakSelf getStreamBaseDesc];
        CMSampleBufferRef buff = NULL;
        CMFormatDescriptionRef format = NULL;
        OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &format);
        if (status) { //失败
            return;
        }
        CMSampleTimingInfo timing = { CMTimeMake(1, weakSelf.sampleRate), CMTimeMake([[NSDate date] timeIntervalSince1970] * 1000000.0, 1000000.0), kCMTimeInvalid };
        status = CMSampleBufferCreate(kCFAllocatorDefault, NULL, false, NULL, NULL, format, (CMItemCount)inNumberFrames, 1, &timing, 0, NULL, &buff);
        if (status) { //失败
            CFRelease(buff);
            return;
        }
        status = CMSampleBufferSetDataBufferFromAudioBufferList(buff, kCFAllocatorDefault, kCFAllocatorDefault, 0, &audioBufferList);
        if (status) { //失败
            CFRelease(buff);
            return;
        }
        if (weakSelf.audioProcessingCallback) {
            weakSelf.audioProcessingCallback(buff);
        }
        CFRelease(buff);
    });
}

- (void)startCapture
{
    NSError *error = nil;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord  withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetooth  error:&error];
    [session setActive:YES error:nil];
    AudioUnitInitialize(_audioComponentInstance);
    AudioOutputUnitStart(_audioComponentInstance);
}

- (void)stopCapture
{
    AudioOutputUnitStop(_audioComponentInstance);
    AudioUnitUninitialize(_audioComponentInstance);
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setActive:NO error:nil];

}
@end
