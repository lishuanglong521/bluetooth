//
//  CustomAVAudioSession.m
//  ECCarRace
//
//  Created by user on 16/6/30.
//  Copyright © 2016年 eyescontrol. All rights reserved.
//

#import "CustomAVAudioSession.h"

@implementation CustomAVAudioSession

static id _instance;
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (void)phoneAVAudioSession{
    
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];

}

- (void)blueToothAVAudioSession{
    
    [[AVAudioSession sharedInstance]
     setCategory: AVAudioSessionCategoryPlayAndRecord
     withOptions:AVAudioSessionCategoryOptionAllowBluetooth
     error: nil];
    [[AVAudioSession sharedInstance]
     setMode:AVAudioSessionModeVoiceChat
     error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error: nil];

}
- (void)blueToothInput{
    NSArray *availableInputs = [[AVAudioSession sharedInstance] availableInputs];
    NSLog(@"%@",availableInputs);
    //built in Ble for your case
    for (AVAudioSessionPortDescription *input in availableInputs) {
        if ([[input portType]isEqualToString:AVAudioSessionPortBluetoothHFP]) {
            NSError *portErr = nil;
            [[AVAudioSession sharedInstance] setPreferredInput:input error:&portErr];
            return;
        }
        if ([[input portType]isEqualToString:AVAudioSessionPortBuiltInMic]) {
           
            //[self phoneAVAudioSession];
            [[ECDevice sharedInstance].VoIPManager enableLoudsSpeaker:YES];
           
            
        }
    }
}
@end
