//
//  WWengAUAudioCapture.m
//  ShortVideo
//
//  Created by Jonathan on 2018/4/23.
//  Copyright © 2018年 WWeng. All rights reserved.
//

#import "WWengAUAudioCapture.h"

#define WWengAudioProcessingQueue "WWeng.AudioProcessingQueue"

@interface WWengAUAudioCapture ()
{
    AudioComponentDescription _acDesc;
    AudioComponent _audioComponent;
}
@property (nonatomic, assign) double sampleRate;
@property (nonatomic, assign) AudioStreamBasicDescription streamDesc;
@property (nonatomic, assign) AudioComponentInstance audioComponentInstance;
@property (nonatomic, strong) dispatch_queue_t audioProcessingQueue;
@end

@implementation WWengAUAudioCapture
- (instancetype)initWithSampleRate:(double)sampleRate
{
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;
        [self _setup];
    }
    return self;
}

- (instancetype)init
{
    self = [self initWithSampleRate:44100.0];
    if (self) {
        
    }
    return self;
}

- (dispatch_queue_t)audioProcessingQueue
{
    if(!_audioProcessingQueue){
        _audioProcessingQueue = dispatch_queue_create(WWengAudioProcessingQueue, DISPATCH_QUEUE_SERIAL);
    }
    return _audioProcessingQueue;
}

- (void)_setup
{
    _streamDesc.mSampleRate = _sampleRate;
    _streamDesc.mFormatID = kAudioFormatLinearPCM;
    _streamDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    _streamDesc.mChannelsPerFrame = 2;
    _streamDesc.mFramesPerPacket = 1;
    _streamDesc.mBitsPerChannel = 16;
    _streamDesc.mBytesPerFrame = _streamDesc.mBitsPerChannel / 8 * _streamDesc.mChannelsPerFrame;
    _streamDesc.mBytesPerPacket = _streamDesc.mBytesPerFrame * _streamDesc.mFramesPerPacket;
    
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
    micCallback.inputProc = _micCallBackFun;
    
    AudioUnitSetProperty(_audioComponentInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &micCallback, sizeof(micCallback));
}

OSStatus _micCallBackFun(void *inRefCon,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp *inTimeStamp,
                        UInt32 inBusNumber,
                        UInt32 inNumberFrames,
                        AudioBufferList *ioData)
{
    @autoreleasepool {
        WWengAUAudioCapture *ref = (__bridge WWengAUAudioCapture *)inRefCon;
        
        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 2;
        
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0] = buffer;
        
        AudioUnitRender(ref.audioComponentInstance,
                        ioActionFlags,
                        inTimeStamp,
                        1,
                        inNumberFrames,
                        &bufferList);
        [ref _toSampleBuffer:bufferList inNumberFrames:inNumberFrames];
        return noErr;
    }
}
- (void)_toSampleBuffer:(AudioBufferList)audioBufferList inNumberFrames:(UInt32)inNumberFrames
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.audioProcessingQueue, ^{
        AudioStreamBasicDescription asbd = weakSelf.streamDesc;
        CMSampleBufferRef buff = NULL;
        CMFormatDescriptionRef format = NULL;
        OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &format);
        if (status) { //失败
            return;
        }
        CMSampleTimingInfo timing = { CMTimeMake(1, weakSelf.sampleRate), kCMTimeZero, kCMTimeInvalid };
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
    AudioUnitUninitialize(_audioComponentInstance);
    AudioOutputUnitStop(_audioComponentInstance);
}
@end
