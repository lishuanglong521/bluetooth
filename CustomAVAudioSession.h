//
//  CustomAVAudioSession.h
//  ECCarRace
//
//  Created by user on 16/6/30.
//  Copyright © 2016年 eyescontrol. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CustomAVAudioSession : NSObject




/**
 *  单例
 *
 *  @return
 */
+ (instancetype)sharedInstance;

/**
 * 手机扬声器播放
 */
- (void)phoneAVAudioSession;

/**
 * 蓝牙播放
 */

- (void)blueToothAVAudioSession;

/**
 * 蓝牙Input
 */
- (void)blueToothInput;
@end
