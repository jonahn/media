//
//  JNACCEncoder.m
//  Media
//
//  Created by Jonathan on 2018/5/21.
//  Copyright © 2018年 JNStream. All rights reserved.
//

#import "JNACCEncoder.h"
@interface JNACCEncoder ()
{
    dispatch_queue_t _encodeQueue;
}
@property (nonatomic, assign) AudioConverterRef audioConverter;
@end
@implementation JNACCEncoder
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self jn__setup];
    }
    return self;
}

- (void)jn__setup
{
    _encodeQueue = dispatch_queue_create("jn.ACCEncoder", DISPATCH_QUEUE_SERIAL);
    _sampleRate = 44100;
    _kbps = 48;
}

//OSStatus jn_audioProcessingCallBack(AudioConverterRef)

- (OSStatus)run
{
    if (_running) {
        return noErr;
    }
    _running = YES;
    AudioStreamBasicDescription inputAudioDes = {
        .mSampleRate = _sampleRate,
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger,
        .mChannelsPerFrame = 2,
        .mFramesPerPacket = 1,
        .mBitsPerChannel = 16,
        .mBytesPerFrame = 4,
        .mBytesPerPacket = 4,
    };
    AudioStreamBasicDescription outAudioDes = {
        .mFormatID = kAudioFormatMPEG4AAC,
        .mFormatFlags = kMPEG4Object_AAC_LC,
        .mChannelsPerFrame = 1,
        0
    };
    UInt32 outDesSize = sizeof(outAudioDes);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &outDesSize, &outAudioDes);
    OSStatus status = AudioConverterNew(&inputAudioDes, &outAudioDes, &_audioConverter);
    if (status != noErr) {
        _running = NO;
        return status;
    }
    UInt32 kbps = _kbps * 1000;
    UInt32 kbpsSize = sizeof(kbps);
    status = AudioConverterSetProperty(_audioConverter, kAudioConverterEncodeBitRate, kbpsSize, &kbps);
    if (status != noErr) {
        _running = NO;
    }
    return status;
}

- (void)stop
{
    if (!_running) {
        return;
    }
    AudioConverterDispose(_audioConverter);
    _audioConverter = nil;
    _running = NO;
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (!_running) {
        return;
    }
    CFRetain(sampleBuffer);
    dispatch_async(_encodeQueue, ^{
       
        
    });
}
@end
