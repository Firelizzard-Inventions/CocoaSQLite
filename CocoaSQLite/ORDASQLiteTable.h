//
//  ORDASQLiteTable.h
//  ORDA
//
//  Created by Ethan Reesor on 8/24/13.
//  Copyright (c) 2013 Firelizzard Inventions. All rights reserved.
//

#import <ORDA/ORDA-dev.h>

/**
 * ORDASQLiteTable is the ORDA SQLite implementation of ORDATable.
 */
@interface ORDASQLiteTable : ORDATableImpl

- (id)selectWhereRowidEquals:(NSNumber *)rowid;

@end
