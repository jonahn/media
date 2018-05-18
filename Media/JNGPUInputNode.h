//
//  JNImageOutputConnection.h
//  Media
//
//  Created by Jonathan on 2018/5/16.
//  Copyright © 2018年 JN. All rights reserved.
//
//  拿到buffer送入这个实例中处理
//  从GPUImageVideoCamera.h中拆出来的
//

#import <GPUImage.h>

@interface JNGPUInputNode : GPUImageOutput

/**
 @param fmt 输入buffer格式
 - kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
 - kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
 - kCVPixelFormatType_32BGRA
 @return ins
 */
- (instancetype)initWithInputFmt:(UInt32)fmt;

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end
