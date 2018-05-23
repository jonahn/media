//
//  JNAACEncoder.m
//  Media
//
//  Created by Jonathan on 2018/5/21.
//  Copyright © 2018年 JNStream. All rights reserved.
//

#import "JNAACEncoder.h"

typedef struct {
    void *pcmData;
    UInt32 pcmLength;
}JNAudioConverterFillComplexInput;

@interface JNAACEncoder ()
{
    dispatch_queue_t _encodeQueue;
}
@property (nonatomic, assign) AudioConverterRef audioConverter;
@end
@implementation JNAACEncoder
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
    _encodeQueue = dispatch_queue_create("jn.AACEncoder", DISPATCH_QUEUE_SERIAL);
    _sampleRate = 44100;
    _kbps = 48;
}

OSStatus jn__audioConverterComplexInputDataProc(AudioConverterRef inAudioConverter,UInt32 * ioNumberDataPacket,AudioBufferList *ioData,AudioStreamPacketDescription ** outDataPacketDescription,void *inputData)
{
    JNAudioConverterFillComplexInput *input = (JNAudioConverterFillComplexInput *)inputData;
    ioData->mBuffers[0].mData = input->pcmData;
    ioData->mBuffers[0].mDataByteSize = input->pcmLength;
    ioData->mBuffers[0].mNumberChannels = 2;
    *ioNumberDataPacket = 1;
    return noErr;
}

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
        .mChannelsPerFrame = 2,
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
        return status;
    }
    return status;
}

- (void)stop
{
    if (!_running) {
        return;
    }
    AudioConverterDispose(_audioConverter);
    _audioConverter = NULL;
    _running = NO;
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (!_running) {
        return;
    }
    CFRetain(sampleBuffer);
    __weak typeof(self) weakSelf = self;
    dispatch_async(_encodeQueue, ^{
        __strong typeof(weakSelf) sSelf = weakSelf;
        // 从samplebuffer众获取blockbuffer
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        size_t  pcmLength = 0;
        char * pcmData = NULL;
        OSStatus status =  CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &pcmLength, &pcmData);
        if (status != noErr) {
            CFRelease(sampleBuffer);
            return ;
        }

        
        JNAudioConverterFillComplexInput input = {
            .pcmData = pcmData,
            .pcmLength = (UInt32)pcmLength
        };
        
        char *outputBuffer = malloc(pcmLength);//申请pcm长度的空间
        memset(outputBuffer, 0, pcmLength);//所有值都设置为0
        AudioBufferList outputBufferList;
        outputBufferList.mNumberBuffers = 1;
        outputBufferList.mBuffers[0].mData = outputBuffer;
        outputBufferList.mBuffers[0].mDataByteSize = pcmLength;
        outputBufferList.mBuffers[0].mNumberChannels = 2;
        
        UInt32 packetSize = 1;
//        AudioStreamPacketDescription *outputPacketDes = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * packetSize);
        
        status = AudioConverterFillComplexBuffer(sSelf.audioConverter, jn__audioConverterComplexInputDataProc, &input, &packetSize, &outputBufferList, NULL);
//        free(outputPacketDes);

        if (status != noErr) {
            CFRelease(sampleBuffer);
            free(outputBuffer);
            return;
        }
        NSData *rawAAC = [NSData dataWithBytes:outputBufferList.mBuffers[0].mData length:outputBufferList.mBuffers[0].mDataByteSize];
        free(outputBuffer);
        if (sSelf.processingEncodedData) {
            sSelf.processingEncodedData(rawAAC);
        }
        CFRelease(sampleBuffer);
    });
}

@end
