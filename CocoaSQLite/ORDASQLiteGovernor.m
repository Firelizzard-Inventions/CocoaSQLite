//
//  ORDASQLiteGovernorImpl.m
//  ORDA
//
//  Created by Ethan Reesor on 8/11/13.
//  Copyright (c) 2013 Firelizzard Inventions. Some rights reserved, see license.
//

#import "ORDASQLiteGovernor.h"

#import <ORDA/ORDA-dev.h>

#import "ORDASQLiteConsts.h"
#import "ORDASQLiteDriver.h"
#import "ORDASQLiteErrorResult.h"
#import "ORDASQLiteStatement.h"
#import "ORDASQLiteTable.h"

@interface ORDASQLiteGovernor ()

@property (readonly) NSMutableDictionary * tables;

@end

void update_hook(void * data, int type, char const * dbname, char const * tbname, sqlite3_int64 rowid)
{
	ORDATableUpdateType ordaType = kORDAUnknownTableUpdateType;
	switch (type) {
		case SQLITE_INSERT:
			ordaType = kORDARowInsertTableUpdateType;
			break;
			
		case SQLITE_UPDATE:
			ordaType = kORDARowUpdateTableUpdateType;
			break;
			
		case SQLITE_DELETE:
			ordaType = kORDARowDeleteTableUpdateType;
			break;
	}
	
	ORDASQLiteGovernor * gov = (__bridge ORDASQLiteGovernor *)(data);
	
	[gov.tables[@(tbname)] tableUpdateDidOccur:ordaType toRowWithKey:@(rowid)];
}

@implementation ORDASQLiteGovernor

- (id)initWithURL:(NSURL *)URL
{
	if (!(self = [super init]))
		return nil;
	
	if (self.code != kORDASucessResultCode)
		return self;
	
	if (!URL)
		return (ORDASQLiteGovernor *)[ORDASQLiteErrorResult errorWithCode:(ORDASQLiteResultCodeError)kORDANilURLErrorResultCode];
	
	NSString * path = URL.relativePath;
	if (!path)
		return (ORDASQLiteGovernor *)[ORDASQLiteErrorResult errorWithCode:(ORDASQLiteResultCodeError)kORDABadURLErrorResultCode];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
		return (ORDASQLiteGovernor *)[ORDASQLiteErrorResult errorWithCode:kORDASQLiteFileDoesNotExistErrorResultCode];
	
	int status = sqlite3_open([path cStringUsingEncoding:NSUTF8StringEncoding], &_connection);
	if (status != SQLITE_OK)
		return (ORDASQLiteGovernor *)[ORDASQLiteErrorResult errorWithCode:(ORDACode)kORDAConnectionErrorResultCode andSQLiteErrorCode:status];
	
	sqlite3_update_hook(self.connection, &update_hook, (__bridge void *)self);
	
	_tables = [NSMutableDictionary dictionary];
	
	return self;
}

- (void)dealloc
{
	if (_connection)
		sqlite3_close(_connection);
}

- (id<ORDAStatement>)createStatement:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2)
{
	va_list args;
	va_start(args, format);
	NSString * statementSQL = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	
	return [ORDASQLiteStatement statementWithGovernor:self withSQL:statementSQL];
}

- (id<ORDATable>)createTable:(NSString *)tableName
{
	if (self.tables[tableName])
		return self.tables[tableName];
	
	return self.tables[tableName] = [ORDASQLiteTable tableWithGovernor:self withName:tableName];
}

@end
