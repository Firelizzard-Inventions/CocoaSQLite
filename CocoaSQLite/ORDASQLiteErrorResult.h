//
//  ORDASQLiteErrorResult.h
//  ORDA
//
//  Created by Ethan Reesor on 8/13/13.
//  Copyright (c) 2013 Firelizzard Inventions. Some rights reserved, see license.
//

#import <ORDA/ORDA-dev.h>

#import "ORDASQLiteConsts.h"

/**
 * ORDASQLiteErrorResult is an ORDA SQLite subclass of ORDADriverResult.
 */
@interface ORDASQLiteErrorResult : ORDADriverResult

@property (readonly) int status;

+ (ORDADriverResult *)errorWithCode:(ORDASQLiteResultCodeError)code;
+ (ORDASQLiteErrorResult *)errorWithCode:(ORDASQLiteResultCodeError)code andSQLiteErrorCode:(int)code;
+ (ORDASQLiteErrorResult *)errorWithSQLiteErrorCode:(int)status;
- (id)initWithCode:(ORDASQLiteResultCodeError)code andSQLiteErrorCode:(int)status;

@end
