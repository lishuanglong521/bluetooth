//
//  BlueTooth.h
//  BluetoothDemo
//
//  Created by LI on 16/6/27.
//  Copyright © 2016年 LI. All rights reserved.
//

#import "BlueTooth.h"

@interface BlueTooth ()

@property (nonatomic, assign)  CBCentralManagerState state;

@property (nonatomic, strong) NSMutableArray *DeviceArray;
@property (nonatomic, strong) NSMutableArray *ServiceArray;
@property (nonatomic, strong) NSMutableArray *CharacteristicArray;

@property (nonatomic, strong) CBPeripheral *ConnectionDevice;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy)  ScanDevicesCompleteBlock scanBlock;
@property (nonatomic, copy)  ConnectionDeviceBlock connectionBlock;
@property (nonatomic, copy)  ServiceAndCharacteristicBlock serviceAndcharBlock;
@end

@implementation BlueTooth

#pragma mark - 自定义方法



static id _instance;
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    
    
    self = [super init];
    if (self) {
        _manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
        _ServiceArray = [[NSMutableArray alloc] init];
        _CharacteristicArray = [[NSMutableArray alloc] init];
        _DeviceArray = [[NSMutableArray alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectType:) name:BLE_ACTION_NAME object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ValueChange:) name:NotiValueChange object:nil];
    }
    return self;
}

- (void)selectType:(NSNotification *)notifi{
    _bleType = [notifi.object integerValue];
    
}

- (void)startScanDevicesWithInterval:(NSUInteger)timeout CompleteBlock:(ScanDevicesCompleteBlock)block {
    NSLog(@"开始扫描设备");
    [self.DeviceArray removeAllObjects];
    [self.ServiceArray removeAllObjects];
    [self.CharacteristicArray removeAllObjects];
    self.scanBlock = block;
    [self.manager scanForPeripheralsWithServices:nil  options:@{CBCentralManagerScanOptionAllowDuplicatesKey : [NSNumber numberWithBool:YES]}];
    [self performSelector:@selector(stopScanDevices) withObject:nil afterDelay:timeout];
}

- (void)stopScanDevices {
    NSLog(@"扫描设备结束");
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopScanDevices) object:nil];
    [self.manager stopScan];
    if (self.scanBlock) {
        self.scanBlock(self.DeviceArray);
    }
    self.scanBlock = nil;
}

- (void)connectionWithDeviceUUID:(NSString *)uuid TimeOut:(NSUInteger)timeout CompleteBlock:(ConnectionDeviceBlock)block {
    self.connectionBlock = block;
    [self performSelector:@selector(connectionTimeOut) withObject:nil afterDelay:timeout];
    for (CBPeripheral *device in self.DeviceArray) {
        if ([device.identifier.UUIDString isEqualToString:uuid]) {
            [self.manager connectPeripheral:device options:@{ CBCentralManagerScanOptionAllowDuplicatesKey:@YES }];
            break;
        }
    }
}

- (void)disconnectionDevice {
    NSLog(@"断开设备连接");
    [self.ServiceArray removeAllObjects];
    [self.CharacteristicArray removeAllObjects];
    [self.manager cancelPeripheralConnection:self.ConnectionDevice];
    self.ConnectionDevice = nil;
}

- (void)discoverServiceAndCharacteristicWithInterval:(NSUInteger)time CompleteBlock:(ServiceAndCharacteristicBlock)block {
    [self.ServiceArray removeAllObjects];
    [self.CharacteristicArray removeAllObjects];
    self.serviceAndcharBlock = block;
    self.ConnectionDevice.delegate = self;
    
    [self.ConnectionDevice discoverServices:nil];
    
    [self performSelector:@selector(discoverServiceAndCharacteristicWithTime) withObject:nil afterDelay:time];
}

- (void)writeCharacteristicWithServiceUUID:(NSString *)sUUID CharacteristicUUID:(NSString *)cUUID data:(NSData *)data {
    for (CBService *service in self.ConnectionDevice.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for (CBCharacteristic *characteristic in service.characteristics) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                    [self.ConnectionDevice writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                }
            }
        }
    }
}

- (void)setNotificationForCharacteristicWithServiceUUID:(NSString *)sUUID CharacteristicUUID:(NSString *)cUUID enable:(BOOL)enable {
    for (CBService *service in self.ConnectionDevice.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for (CBCharacteristic *characteristic in service.characteristics) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                    [self.ConnectionDevice setNotifyValue:enable forCharacteristic:characteristic];
                }
            }
        }
    }
}
-(void)readCharacteristicWithServiceUUID:(NSString *)sUUID CharacteristicUUID:(NSString *)cUUID{
    for (CBService *service in self.ConnectionDevice.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for (CBCharacteristic *characteristic in service.characteristics) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                    [self.ConnectionDevice readValueForCharacteristic:characteristic];
                }
            }
        }
    }
}

#pragma mark - 私有方法

- (void)connectionTimeOut {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimeOut) object:nil];
    if (self.connectionBlock) {
        self.connectionBlock(nil, [self wrapperError:@"连接设备超时!" Code:400]);
    }
    self.connectionBlock = nil;
}

- (void)discoverServiceAndCharacteristicWithTime {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimeOut) object:nil];
    if (self.serviceAndcharBlock) {
        self.serviceAndcharBlock(self.ServiceArray, self.CharacteristicArray, [self wrapperError:@"发现服务和特征完成!" Code:400]);
    }
    self.connectionBlock = nil;
}

- (NSError *)wrapperError:(NSString *)msg Code:(NSInteger)code {
    NSError *error = [NSError errorWithDomain:msg code:code userInfo:nil];
    return error;
}

#pragma mark - CBCentralManagerDelegate代理方法

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"当前的设备状态:%ld", (long)central.state);
    self.state = central.state;
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"发现设备:%@", peripheral);
    if (![self.DeviceArray containsObject:peripheral]) {
        [self.DeviceArray addObject:peripheral];
    }
   
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectionTimeOut) object:nil];
    NSLog(@"连接设备成功:%@", peripheral);
    
    self.ConnectionDevice = peripheral;
    self.ConnectionDevice.delegate = self;
    
    if (self.connectionBlock) {
        self.connectionBlock(peripheral, [self wrapperError:@"连接成功!" Code:401]);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                      target:self
                                                    selector:@selector(detectRSSI)
                                                    userInfo:nil
                                                     repeats:YES];
    });

    
}
- (void)detectRSSI
{
    
        [ self.ConnectionDevice readRSSI];
    
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{
    if (error) {
        NSLog(@"didDisconnectPeripheral断开发生错误,错误信息:%@", error);
    }
   
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{
    if (error) {
        NSLog(@"didFailToConnectPeripheral断开发生错误,错误信息:%@", error);
    }
  
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"搜索服务发生错误,错误信息:%@", error);
    }
    for (CBService *service in peripheral.services) {
        [self.ServiceArray addObject:service];
        [self.ConnectionDevice discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"搜索特征发生错误,错误信息:%@", error);
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
        [self.CharacteristicArray addObject:characteristic];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"didWriteValueForCharacteristic接收数据发生错误,%@", error);
        return;
    }
    NSLog(@"didWriteValueForCharacteristic写入值发生改变,%@", error);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"didUpdateValueForCharacteristic接收数据发生错误,%@", error);
        return;
    }
    NSString *string=[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
     if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFF3"]]) {
    [[NSNotificationCenter defaultCenter] postNotificationName:NotiValueChange object:characteristic.value];
      }
    NSLog(@"didUpdateValueForCharacteristic接收到的数据%@", string);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"didUpdateNotificationStateForCharacteristic接收数据发生错误,%@", error);
        return;
    }
    if (characteristic.isNotifying) {
       // [peripheral readValueForCharacteristic:characteristic];
    } else { // Notification has stopped
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        NSLog(@"%@",[NSString stringWithFormat:@"Notification stopped on %@.  Disconnecting", characteristic]);
        //[manager cancelPeripheralConnection:self.peripheral];
    }

    NSString *string=[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSLog(@"didUpdateNotificationStateForCharacteristic收到的数据为%@", string);
}
#pragma mark - getter
- (BOOL)isReady {
    return self.state == CBCentralManagerStatePoweredOn ? YES : NO;
}

- (BOOL)isConnection {
    return self.ConnectionDevice.state == CBPeripheralStateConnected ? YES : NO;
}





-(void)ValueChange:(NSNotification *)noti{
    NSData * data = noti.object;
    Byte * resultByte = (Byte *)[data bytes];
    if (resultByte) {
        ///FM键
        if (resultByte[0] == 70 && resultByte[1] == 77 ) {
            
            
            //对讲回到FM
            [[NSNotificationCenter defaultCenter]postNotificationName:BACK_TO_FM object:nil userInfo:nil];
            
            [self performSelector:@selector(playFM) withObject:nil afterDelay:0.3];
            
            
            
        }
        
        // 滚轮向上
        if (resultByte[0] == 2 && resultByte[1] == 1 && resultByte[2] == 3) {
            
            switch (_bleType ) {
                case BLEFM:
                    [[NSNotificationCenter defaultCenter]postNotificationName:LAST_FM_CHANNL object:nil userInfo:nil];
                    break;
                case BLEPTT:
                    [self performSelector:@selector(postNotifiLastPTT) withObject:nil afterDelay:0.5];
                    break;
                default:
                    break;
            }
            
        }
        //滚轮向下
        if (resultByte[0] == 2 && resultByte[1] == 1 && resultByte[2] == 1) {
            switch (_bleType ) {
                case BLEFM:
                    [[NSNotificationCenter defaultCenter]postNotificationName:NEXT_FM_CHANNL object:nil userInfo:nil];
                    break;
                case BLEPTT:
                    [self performSelector:@selector(postNotifiNextPTT) withObject:nil afterDelay:0.5];
                    
                    break;
                default:
                    break;
            }
            
            
        }
        
        //ptt键
        //按下时间如果<1s
        if (resultByte[0] == 80 && resultByte[1] == 84 && resultByte[2] == 84 && resultByte[3] == 48 ) {
            [[NSNotificationCenter defaultCenter]postNotificationName:BACK_TO_PTT object:nil userInfo:nil];
        }
        //按下时间如果>1s
        if (resultByte[0] == 80 && resultByte[1] == 84 && resultByte[2] == 84 && resultByte[3] == 49 ) {
            if (_isGrabOrFree) {
                return;
            }
            [[NSNotificationCenter defaultCenter]postNotificationName:GRAB_MIFRO_PHONE object:nil userInfo:nil];
            _isGrabOrFree = !_isGrabOrFree;
            [[NSUserDefaults standardUserDefaults]setObject:@"BlueTooth" forKey:DeviceName];
        }
        //按下>1s后松开键
        if (resultByte[0] == 80 && resultByte[1] == 84 && resultByte[2] == 84 && resultByte[3] == 50 ) {
            _isGrabOrFree = NO;
            [[NSNotificationCenter defaultCenter]postNotificationName:FREE_MIFRO_PHONE object:nil userInfo:nil];
              [[NSUserDefaults standardUserDefaults]setObject:@"Phone" forKey:DeviceName];
        }
        
        for(int i=0;i<[data length];i++){
            printf("testByteFFF3[%d] = %d\n",i,resultByte[i]);
            
        }
        
    }
    
    
}
- (void)playFM{
    [[NSNotificationCenter defaultCenter]postNotificationName:BLE_FM object:nil userInfo:nil];
}
//滚动滑轮FM,PTT
- (void)postNotifiLastPTT{
    [[NSNotificationCenter defaultCenter]postNotificationName:LAST_PTT_CHANNL object:nil userInfo:nil];
}
- (void)postNotifiNextPTT{
    [[NSNotificationCenter defaultCenter]postNotificationName:NEXT_PTT_CHANNL object:nil userInfo:nil];
}

@end
