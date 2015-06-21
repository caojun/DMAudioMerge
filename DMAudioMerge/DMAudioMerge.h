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


@import AVFoundation;

@class DMAudioMerge;

#pragma mark - DMAudioMergeDelegate
@protocol DMAudioMergeDelegate <NSObject>

@optional
/**
 *  创建目标文件
 *
 *  @param merge
 *
 *  @return YES / NO
 */
- (BOOL)audioMergeCreateDestFile:(DMAudioMerge *)merge;

/**
 *  保存数据
 *
 *  @param buf 数据
 *  @param len 长度
 *
 *  @return YES / NO
 */
- (BOOL)audioMergeWriteBuf:(unsigned char *)buf len:(long)len;

/**
 *  关闭文件
 *
 *  @param merge
 */
- (void)audioMergeCloseDestFile:(DMAudioMerge *)merge;

- (void)audioMergeFinish:(DMAudioMerge *)merge isSuccess:(BOOL)isSuccess error:(NSError *)error;

@end



#pragma mark - DMAudioMerge
/**
 *  音频合成器, 默认合并成lpcm格式
 */
@interface DMAudioMerge : NSObject

@property (nonatomic, assign) int tag;

/**
 *  源始文件1
 */
@property (nonatomic, copy) NSString *m_srcFile1;

/**
 *  源始文件1音量, 0 ~ 1
 */
@property (nonatomic, assign) float m_file1Volume;

/**
 *  源始文件2
 */
@property (nonatomic, copy) NSString *m_srcFile2;

/**
 *  源始文件2音量，0 ~ 1
 */
@property (nonatomic, assign) float m_file2Volume;

/**
 *  保存文件
 */
@property (nonatomic, copy) NSString *m_destFile;

/**
 *  保存文件的声音，0 ~ 1
 */
@property (nonatomic, assign) float m_destFileVolume;

/**
 *  合成的格式, 有默认的参数
 *   mSampleRate = 44100;
 *   mFormatID = kAudioFormatLinearPCM;
 *   mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
 *   mBytesPerPacket = 2;
 *   mFramesPerPacket = 1;
 *   mBytesPerFrame = 2;
 *   mChannelsPerFrame = 1;
 *   mBitsPerChannel = 16;
 */
@property (nonatomic, assign) AudioStreamBasicDescription m_destFormat;


/**
 *  代理
 */
@property (nonatomic, weak) id<DMAudioMergeDelegate> delegate;


#pragma mark -
+ (instancetype)audioMerge;
+ (instancetype)audioMergeDestFile:(NSString *)destFile
                          srcFile1:(NSString *)file1
                          srcFile2:(NSString *)file2;

+ (instancetype)audioMergeDestFile:(NSString *)destFile
                          srcFile1:(NSString *)file1
                    srcFile1Volume:(float)file1Volume
                          srcFile2:(NSString *)file2
                    srcFile2Volume:(float)file2Volume;

+ (instancetype)audioMergeDestFile:(NSString *)destFile
                    destFileVolume:(float)destFileVolume
                          srcFile1:(NSString *)file1
                    srcFile1Volume:(float)file1Volume
                          srcFile2:(NSString *)file2
                    srcFile2Volume:(float)file2Volume;


- (instancetype)initWithDestFile:(NSString *)destFile
                        srcFile1:(NSString *)file1
                        srcFile2:(NSString *)file2;

- (instancetype)initWithDestFile:(NSString *)destFile
                        srcFile1:(NSString *)file1
                  srcFile1Volume:(float)file1Volume
                        srcFile2:(NSString *)file2
                  srcFile2Volume:(float)file2Volume;

- (instancetype)initWithDestFile:(NSString *)destFile
                  destFileVolume:(float)destFileVolume
                        srcFile1:(NSString *)file1
                  srcFile1Volume:(float)file1Volume
                        srcFile2:(NSString *)file2
                  srcFile2Volume:(float)file2Volume;

/**
 *  合并, 合并过程中文件路径不能被释放掉，否则会出错
 */
- (void)start;

- (void)stop;

- (void)deleteSrcFile;

@end
