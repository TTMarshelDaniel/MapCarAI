//
//  MapCarAI.h
//  GoCGM_Passenger
//
//  Created by palnar on 28/02/18.
//  Copyright © 2018 palnar. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "CarMarker.h"

@interface MapCarAI : NSObject

@property (nonatomic, readonly) CarMarker *marker;

+(instancetype)AIWithMapView:(GMSMapView *)mapView;
 
-(void)moveTo:(CLLocationCoordinate2D)coordinate;

@end
