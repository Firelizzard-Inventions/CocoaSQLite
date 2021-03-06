//
//  ORDASQLiteTable.m
//  ORDA
//
//  Created by Ethan Reesor on 8/24/13.
//  Copyright (c) 2013 Firelizzard Inventions. All rights reserved.
//

#import "ORDASQLiteTable.h"

#import <TypeExtensions/TypeExtensions.h>
#import <TypeExtensions/String.h>
#import <ORDA/ORDA-dev.h>

#import "ORDASQLiteGovernor.h"
#import "ORDASQLiteErrorResult.h"
#import "ORDASQLiteTableResultEntry.h"
#import "ORDASQLiteTableView.h"


@implementation ORDASQLiteTable {
	id<ORDAStatement> _tableInfoStatement, _foreignKeyListStatement;
}

- (id)initWithGovernor:(id<ORDAGovernor>)governor withName:(NSString *)tableName
{
	if (!(self = [super initWithGovernor:governor withName:tableName]))
		return nil;
	
	if (self.code != kORDASucessResultCode)
		return self;
	
	if (![governor isKindOfClass:[ORDASQLiteGovernor class]])
		return (ORDASQLiteTable *)[ORDASQLiteErrorResult errorWithCode:(ORDASQLiteResultCodeError)kORDAInternalAPIMismatchErrorResultCode];
	
	_tableInfoStatement = [self.governor createStatement:@"PRAGMA table_info(%@)", self.name];
	_foreignKeyListStatement = [self.governor createStatement:@"PRAGMA foreign_key_list(%@)", self.name];
	
	return self;
}

- (NSArray *)columnNames
{
	return _tableInfoStatement.result[@"name"];
}

- (NSArray *)primaryKeyNames
{
	id<ORDAStatementResult> result = _tableInfoStatement.result;
	if (result.isError)
		return nil;
	
	NSMutableArray * keys = [NSMutableArray array];
	for (int i = 0; i < result.rows; i++)
		if (((NSNumber *)result[i][@"pk"]).boolValue)
			[keys addObject:result[i][@"name"]];
	
	return [NSArray arrayWithArray:keys];
}

- (NSArray *)foreignKeyTableNames
{
	return _foreignKeyListStatement.result[@"table"];
}

- (id)selectWhereRowidEquals:(NSNumber *)rowid
{
	id entry = self.rows[rowid];
	if (entry)
		return entry;
	
	id<ORDAStatement> stmt = [self.governor createStatement:@"SELECT * FROM [%@] WHERE rowid = '%@'", self.name, rowid];
	if (stmt.isError)
		return nil;
	
	id<ORDAStatementResult> result = stmt.result;
	if (result.isError)
		return nil;
	if (result.rows < 1)
		return nil;
	
	entry = [ORDASQLiteTableResultEntry tableResultEntryWithRowID:rowid andData:result[0] forTable:self];
	if (entry)
		self.rows[rowid] = entry;
	return entry;
}

- (id<ORDATableResult>)selectWhere:(NSString *)format, ...;
{
	NSString * clause = nil;
	if (!format)
		clause = @"1";
	else {
		va_list args;
		va_start(args, format);
		clause = [[NSString alloc] initWithFormat:format arguments:args];
		va_end(args);
	}
	
	id<ORDAStatement> stmt = [self.governor createStatement:@"SELECT rowid as 'rowid' FROM [%@] WHERE %@", self.name, clause];
	if (stmt.isError)
		return (id<ORDATableResult>)stmt;
	
	id<ORDAStatementResult> result = stmt.result;
	if (result.isError)
		return (id<ORDATableResult>)result;
	
	NSMutableArray * entries = [NSMutableArray arrayWithCapacity:result.rows];
	for (NSNumber * rowid in result[@"rowid"])
		[entries addObject:[self selectWhereRowidEquals:rowid]];
	
	return [ORDATableResultImpl tableResultWithArray:entries];
}

- (id<ORDATableResult>)insertValues:(id)values ignoreCase:(BOOL)ignoreCase;
{
	NSMutableArray * _columns = [NSMutableArray arrayWithCapacity:self.columnNames.count];
	NSMutableArray * _values = [NSMutableArray arrayWithCapacity:self.columnNames.count];
	
	if (ignoreCase && [values respondsToSelector:@selector(allKeys)]) {
		NSArray * keys = [values allKeys];
		for (NSString * column in self.columnNames) {
			id value = nil;
			for (NSString * key in keys)
				if ([column isEqualToStringIgnoreCase:key]) {
					value = [values valueForKey:column];
					break;
				}
			
			if (value) {
				[_columns addObject:column];
				[_values addObject:[NSString stringWithFormat:@"'%@'", value]];
			}
		}
	} else
		for (NSString * column in self.columnNames) {
			id value = [values valueForKey:column];
			if (value) {
				[_columns addObject:column];
				[_values addObject:[NSString stringWithFormat:@"'%@'", value]];
			}
		}
	
	id<ORDAStatement> stmt = [self.governor createStatement:@"INSERT INTO [%@] (%@) VALUES (%@)", self.name, [_columns componentsJoinedByString:@", "], [_values componentsJoinedByString:@", "]];
	if (stmt.isError)
		return (id<ORDATableResult>)stmt;
	
	id<ORDAStatementResult> result = stmt.result;
	if (result.isError)
		return (id<ORDATableResult>)result;
	if (result.lastID < 0)
		return (id<ORDATableResult>)[ORDASQLiteErrorResult errorWithCode:(ORDACode)kORDANoResultRowsForKeyErrorResultCode];
	
	return [ORDATableResultImpl tableResultWithObject:[self selectWhereRowidEquals:@(result.lastID)]];
}

- (id<ORDATableResult>)updateSet:(NSString *)column to:(id)value where:(NSString *)format, ...;
{
	NSString * clause = nil;
	if (!format)
		clause = @"1";
	else {
		va_list args;
		va_start(args, format);
		clause = [[NSString alloc] initWithFormat:format arguments:args];
		va_end(args);
	}
	
	id<ORDAStatement> stmt = [self.governor createStatement:@"UPDATE [%@] SET [%@] = '%@' WHERE %@", self.name, column, value, clause];
	if (stmt.isError)
		return (id<ORDATableResult>)stmt;
	
	id<ORDAStatementResult> result = stmt.result;
	if (result.isError)
		return (id<ORDATableResult>)result;
	
	return [self selectWhere:@"%@", clause];
}

- (id<ORDAStatementResult>)deleteWhere:(NSString *)format, ...
{
	NSString * clause = nil;
	if (!format)
		clause = @"1";
	else {
		va_list args;
		va_start(args, format);
		clause = [[NSString alloc] initWithFormat:format arguments:args];
		va_end(args);
	}
	
	id<ORDAStatement> stmt = [self.governor createStatement:@"SELECT rowid as 'rowid' FROM [%@] WHERE %@", self.name, clause];
	if (stmt.isError)
		return (id<ORDAStatementResult>)stmt;
	
	id<ORDAStatementResult> result = stmt.result;
	if (result.isError)
		return (id<ORDAStatementResult>)result;
	
	for (NSNumber * rowid in result[@"rowid"]) {
		ORDASQLiteTableResultEntry * entry = self.rows[rowid];
		if (entry)
			entry[@"rowid"] = [NSNull null];
	}
	
	stmt = [self.governor createStatement:@"DELETE FROM [%@] WHERE %@", self.name, clause];
	if (stmt.isError)
		return (id<ORDAStatementResult>)stmt;
	
	return stmt.result;
}

- (id<ORDATableView>)viewWhere:(NSString *)format, ...
{
	NSString * clause = nil;
	if (!format)
		clause = @"1";
	else {
		va_list args;
		va_start(args, format);
		clause = [[NSString alloc] initWithFormat:format arguments:args];
		va_end(args);
	}
	
	id<ORDATableView> view = self.views[clause];
	if (view)
		return view;
	
	view = [ORDASQLiteTableView viewWithTable:self andClause:clause];
	if (!view.isError)
		self.views[clause] = view;
	return view;
}

- (id)keyForTableUpdate:(ORDATableUpdateType)type toRowWithKey:(id)key
{
	NSNumber * rowid = key;
	
	if (![rowid isKindOfClass:NSNumber.class]) {
		id<ORDAStatement> stmt = [self.governor createStatement:@"SELECT rowid as 'rowid' FROM [%@] WHERE %@", self.name, key];
		if (stmt.isError)
			return stmt;
		
		id<ORDAStatementResult> result = stmt.result;
		if (result.isError)
			return result;
		if (result.rows < 1)
			return (id<ORDATableResult>)[ORDASQLiteErrorResult errorWithCode:(ORDACode)kORDANoResultRowsForKeyErrorResultCode];
		
		rowid = result[0][@"rowid"];
	}
	
	return rowid;
}

@end
