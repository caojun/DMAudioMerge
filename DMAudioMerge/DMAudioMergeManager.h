/**
 The MIT License (MIT)
 
 Copyright (c) 2015 DreamCao
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

#import <Foundation/Foundation.h>

@class DMAudioMergeManager;
@class DMAudioMerge;

@protocol DMAudioMergeManagerDelegate <NSObject>

@optional
- (void)audioMergeManager:(DMAudioMergeManager *)manager didMergeFinish:(DMAudioMerge *)merge isSuccess:(BOOL)isSuccess error:(NSError *)error;


@end

@interface DMAudioMergeManager : NSObject

@property (nonatomic, weak) id<DMAudioMergeManagerDelegate> delegate;

+ (instancetype)sharedInstance;

// 返回一个ID, 用于 stopWithID
- (int)addAudioMergeWithDestFile:(NSString *)destFile
                   destFileVolume:(float)destFileVolume
                         srcFile1:(NSString *)file1
                   srcFile1Volume:(float)file1Volume
                         srcFile2:(NSString *)file2
                   srcFile2Volume:(float)file2Volume;

- (void)stopAll;

/**
 *  停止某一个
 *
 *  @param ID 由addAudioMergeWithDestFile返回的ID
 */
- (void)stopWithID:(int)ID;

@end
