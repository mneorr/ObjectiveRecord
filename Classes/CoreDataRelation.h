// CoreDataRelation.h
//
// Copyright (c) 2014 Marin Usalj <http://supermar.in>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <CoreData/CoreData.h>

#import "ObjectiveRelation.h"

@interface CoreDataRelation : ObjectiveRelation

+ (instancetype)relationWithManagedObjectClass:(Class)class;
+ (instancetype)relationWithManagedObject:(NSManagedObject *)record relationship:(NSString *)relationshipName;

#pragma mark - Fetch request building

- (instancetype)inContext:(NSManagedObjectContext *)context;
@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;

- (instancetype)inBatchesOf:(NSUInteger)batchSize;

- (NSFetchRequest *)fetchRequest;

#pragma mark Counting

- (CGFloat)sum:(NSString *)attribute;
- (CGFloat)minimum:(NSString *)attribute;
- (CGFloat)maximum:(NSString *)attribute;
- (CGFloat)average:(NSString *)attribute;

#pragma mark - Manipulating entities

- (id)findOrCreate:(NSDictionary *)properties;

- (id)create;
- (id)create:(NSDictionary *)attributes;

- (void)updateAll:(NSDictionary *)attributes;

- (void)deleteAll;

@end