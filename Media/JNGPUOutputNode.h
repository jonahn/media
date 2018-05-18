//
//  JNGPUOutputNode.h
//  Media
//
//  Created by Jonathan on 2018/5/17.
//  Copyright © 2018年 JNStream. All rights reserved.
//
/*
 输出GPUImage处理完成后的buffer
 从GPUImageMovieWriter中拆出来的
 */

#import <Foundation/Foundation.h>
#import <GPUImage.h>

@interface JNGPUOutputNode : GPUImageOutput<GPUImageInput>

@property (nonatomic, assign) CGSize outputSize;
@property (nonatomic, copy)   void(^processingCallback32BGRA)(CVPixelBufferRef pixelBuffer, CMTime timeInfo);
@end
