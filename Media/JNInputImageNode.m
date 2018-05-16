//
//  JNImageOutputConnection.m
//  Media
//
//  Created by Jonathan on 2018/5/16.
//  Copyright © 2018年 JN. All rights reserved.
//

#import "JNInputImageNode.h"

@interface JNInputImageNode ()
{
}
@property (nonatomic, assign) UInt32 fmt;
@property (nonatomic, strong) GLProgram *yuvConversionProgram;
@property (nonatomic, assign) GLint yuvConversionPositionAttribute;
@property (nonatomic, assign) GLint yuvConversionTextureCoordinateAttribute;
@property (nonatomic, assign) GLint yuvConversionLuminanceTextureUniform;
@property (nonatomic, assign) GLint yuvConversionChrominanceTextureUniform;
@property (nonatomic, assign) GLint yuvConversionMatrixUniform;
@end

@implementation JNInputImageNode
- (instancetype)initWithInputFmt:(UInt32)fmt
{
    self = [super init];
    if (self) {
        _fmt = fmt;
        [self jn__setupInputImageNode];
    }
    return self;
}

- (void)jn__setupInputImageNode
{
    self.outputRotation = kGPUImageNoRotation;
    __weak typeof(self) weakSelf = self;
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        if (weakSelf.fmt == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            weakSelf.yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];
        }
        else{
            weakSelf.yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVVideoRangeConversionForLAFragmentShaderString];
        }
        if (!self.yuvConversionProgram.initialized)
        {
            [self.yuvConversionProgram addAttribute:@"position"];
            [self.yuvConversionProgram addAttribute:@"inputTextureCoordinate"];
            
            if (![self.yuvConversionProgram link])
            {
                NSString *progLog = [self.yuvConversionProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [self.yuvConversionProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [self.yuvConversionProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                self.yuvConversionProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        self.yuvConversionPositionAttribute = [self.yuvConversionProgram attributeIndex:@"position"];
        self.yuvConversionTextureCoordinateAttribute = [self.yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
        self.yuvConversionLuminanceTextureUniform = [self.yuvConversionProgram uniformIndex:@"luminanceTexture"];
        self.yuvConversionChrominanceTextureUniform = [self.yuvConversionProgram uniformIndex:@"chrominanceTexture"];
        self.yuvConversionMatrixUniform = [self.yuvConversionProgram uniformIndex:@"colorConversionMatrix"];
        [GPUImageContext setActiveShaderProgram:self.yuvConversionProgram];
        glEnableVertexAttribArray(self.yuvConversionPositionAttribute);
        glEnableVertexAttribArray(self.yuvConversionTextureCoordinateAttribute);
    });
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation
{
    [super addTarget:newTarget atTextureLocation:textureLocation];
    [newTarget setInputRotation:self.outputRotation atIndex:textureLocation];
}
@end
