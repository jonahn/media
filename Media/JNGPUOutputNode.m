//
//  JNGPUOutputNode.m
//  Media
//
//  Created by Jonathan on 2018/5/17.
//  Copyright © 2018年 JNStream. All rights reserved.
//

#import "JNGPUOutputNode.h"
#import <objc/runtime.h>

@interface JNGPUOutputNode ()
{
    CVPixelBufferRef _pixelbuffer;
}
@end

@implementation JNGPUOutputNode

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (BOOL)enabled
{
    return YES;
}
- (void)endProcessing {
    
}

- (CGSize)maximumOutputSize {
    return self.outputSize;
}

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
    if (self.processingCallback32BGRA) {
        self.processingCallback32BGRA(_pixelbuffer, frameTime);
    }
}

- (NSInteger)nextAvailableTextureIndex {
    return 0;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue {
    
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex {
    Ivar iVar = class_getInstanceVariable([newInputFramebuffer class], [@"renderTarget" UTF8String]);
    if (iVar == nil) {
        iVar = class_getInstanceVariable([newInputFramebuffer class], [[NSString stringWithFormat:@"_%@",@"renderTarget"] UTF8String]);
    }
    id propertyVal = object_getIvar(newInputFramebuffer, iVar);
    _pixelbuffer = (__bridge CVPixelBufferRef)(propertyVal);
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex {

}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex {
    
}

- (BOOL)shouldIgnoreUpdatesToThisTarget {
    return NO;
}

- (BOOL)wantsMonochromeInput {
    return NO;
}
@end
