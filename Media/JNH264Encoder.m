//
//  JNH264Encoder.m
//  Media
//
//  Created by Jonathan on 2018/5/18.
//  Copyright © 2018年 JNStream. All rights reserved.
//

#import "JNH264Encoder.h"
@interface JNH264Encoder ()
{
    dispatch_queue_t _encodeQueue;
}
@property (nonatomic, assign) VTCompressionSessionRef vtSession;

@end

@implementation JNH264Encoder
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
    _encodeQueue = dispatch_queue_create("jn.h264encoder", DISPATCH_QUEUE_SERIAL);
    _videoSize = CGSizeMake(360, 640);
    _fps = 15;
    _kbps = 800;
    _gop = 3;
    _running = NO;
}

void jn__processingCallback(void *encoderIns, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                          CMSampleBufferRef sampleBuffer )
{
    if (status != 0) {
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    JNH264Encoder *encoder = (__bridge JNH264Encoder*)encoderIns;
    bool keyframe = !CFDictionaryContainsKey((CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    NSData *sps = nil;
    NSData *pps = nil;
    if (keyframe) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                 0,
                                                                                 &sparameterSet,
                                                                                 &sparameterSetSize,
                                                                                 &sparameterSetCount, 0);
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                     1,
                                                                                     &pparameterSet,
                                                                                     &pparameterSetSize,
                                                                                     &pparameterSetCount, 0);
            if (statusCode == noErr) {
                sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder.processingSpsPps) {
                    encoder.processingSpsPps(sps, pps);
                }
            }
        }
    }
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            NSData *data = [[NSData alloc]initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            if (encoder.processingEncodedData) {
                encoder.processingEncodedData(data, keyframe);
            }
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (OSStatus)run
{
    if (_running) {
        return 0;
    }
    _running = YES;
    OSStatus status;
    VTCompressionOutputCallback outpuCallBack = jn__processingCallback;
    status = VTCompressionSessionCreate(kCFAllocatorDefault, self.videoSize.width, self.videoSize.height, kCMVideoCodecType_H264, NULL, NULL, NULL, outpuCallBack, (__bridge void *)(self), &_vtSession);
    if (status != noErr) {
        _running = NO;
        return status;
    }
    status = VTSessionSetProperty(_vtSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);//实时执行
    status = VTSessionSetProperty(_vtSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    status  = VTSessionSetProperty(_vtSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(self.kbps * 1000));
    status += VTSessionSetProperty(_vtSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(self.kbps * 1000 *2/8), @1]);
    status = VTSessionSetProperty(_vtSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(self.gop));
    status = VTSessionSetProperty(_vtSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(self.fps));
    status = VTCompressionSessionPrepareToEncodeFrames(_vtSession);
    if (status) {
        _running = NO;
    }
    return status;
}

- (void)stop
{
    if (_vtSession == NULL) {
        return;
    }
    VTCompressionSessionCompleteFrames(_vtSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(_vtSession);
    CFRelease(_vtSession);
    _vtSession = NULL;
}

- (void)processVideoBuffer:(CVPixelBufferRef)pixelBuffer timeInfo:(CMTime)timeInfo
{
    if(!_running){
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(_encodeQueue, ^{
        __strong typeof(weakSelf) sSelf = weakSelf;
        VTEncodeInfoFlags flags;
        OSStatus statusCode = VTCompressionSessionEncodeFrame(sSelf.vtSession,
                                                              pixelBuffer,
                                                              timeInfo, kCMTimeInvalid,
                                                              NULL, NULL, &flags);
        if (statusCode != noErr) {
            [sSelf stop];
            return;
        }
    });
}

@end
