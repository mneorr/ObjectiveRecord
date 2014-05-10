// ObjectiveRelation.m
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

#import "ObjectiveRelation.h"

#import "ObjectiveSugar.h"

#import "NSManagedObject+ActiveRecord.h"
#import "NSManagedObject+Mappings.h"

@interface ObjectiveRelation ()

@property (copy, nonatomic) NSArray *objects;

@property (copy, nonatomic) NSArray *select;
@property (copy, nonatomic) NSArray *where;
@property (copy, nonatomic) NSArray *order;
@property (nonatomic) NSUInteger limit;
@property (nonatomic) NSUInteger offset;
@property (copy, nonatomic) NSString *group;
@property (copy, nonatomic) NSString *sectionNameKeyPath;

@end

@implementation ObjectiveRelation

+ (NSArray *)sectionObjects:(NSArray *)objects byKeyPath:(NSString *)keyPath
{
    NSMutableOrderedSet *values = [NSMutableOrderedSet new];
    NSMutableDictionary *groups = [NSMutableDictionary new];
    for (id object in objects) {
        NSString *value = [object valueForKeyPath:keyPath];
        [values addObject:value];

        if (groups[value] == nil)
            groups[value] = [NSMutableArray new];

        [groups[value] addObject:object];
    }

    NSMutableArray *sections = [NSMutableArray arrayWithCapacity:[values count]];
    for (NSString *value in values) {
        [sections addObject:groups[value]];
    }

    return [sections copy];
}

- (id)initWithObjects:(NSArray *)objects {
    if (self = [self init]) {
        _objects = objects;
    }
    return self;
}

- (id)init {
    if (self = [super init]) {
        _where = @[];
        _order = @[];
    }
    return self;
}

#pragma mark - Fetch request building

- (instancetype)all {
    return [self copy];
}

- (instancetype)select:(NSArray *)keyPaths {
    typeof(self) relation = [self copy];
    self.select = keyPaths;
    return relation;
}

- (instancetype)where:(id)condition, ... {
    va_list arguments;
    va_start(arguments, condition);
    typeof(self) relation = [self where:condition arguments:arguments];
    va_end(arguments);

    return relation;
}

- (instancetype)where:(id)condition arguments:(va_list)arguments {
    NSPredicate *predicate = [self predicateFromObject:condition arguments:arguments];
    typeof(self) relation = [self copy];
    relation.where = [relation.where arrayByAddingObject:predicate];
    return relation;
}

- (instancetype)order:(id)order {
    typeof(self) relation = [self copy];
    relation.order = [relation.order arrayByAddingObjectsFromArray:[self sortDescriptorsFromObject:order]];
    return relation;
}

- (instancetype)reverseOrder {
    typeof(self) relation = [self copy];
    relation.order = [relation.order valueForKey:NSStringFromSelector(@selector(reversedSortDescriptor))];
    return relation;
}

- (instancetype)reorder:(id)order {
    typeof(self) relation = [self copy];
    relation.order = @[];
    return [relation order:order];
}

- (instancetype)limit:(NSUInteger)limit {
    typeof(self) relation = [self copy];
    relation.limit = limit;
    return relation;
}

- (instancetype)offset:(NSUInteger)offset {
    typeof(self) relation = [self copy];
    relation.offset = offset;
    return relation;
}

- (instancetype)section:(NSString *)keyPath {
    typeof(self) relation = [self copy];
    relation.sectionNameKeyPath = keyPath;
    return relation;
}

#pragma mark Counting

- (NSUInteger)count {
    return [self.fetchedObjects count];
}

- (BOOL)any {
    return [[self limit:1] count];
}

- (NSUInteger)numberOfSections {
    if (self.sectionNameKeyPath) {
        return [self.fetchedObjects count];
    }
    return 1;
}

- (NSUInteger)numberOfObjectsInSection:(NSUInteger)section {
    if (self.sectionNameKeyPath) {
        return [self.fetchedObjects[section] count];
    }
    return [self.fetchedObjects count];
}

#pragma mark Plucking

- (id)firstObject {
    return [[[self limit:1] fetchedObjects] firstObject];
}

- (id)lastObject {
    return [[self reverseOrder] firstObject];
}

- (id)find:(id)condition, ... {
    va_list arguments;
    va_start(arguments, condition);
    typeof(self) relation = [self where:condition arguments:arguments];
    va_end(arguments);

    return [relation firstObject];
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx
{
    NSAssert(self.sectionNameKeyPath == nil, @"Can't access grouped objects by index");
    return self.fetchedObjects[idx];
}

- (id)objectForKeyedSubscript:(id<NSCopying>)key
{
    NSAssert(self.sectionNameKeyPath != nil, @"Can't access ungrouped objects by index path");
    return [self objectAtIndexPath:(NSIndexPath *)key];
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath {
    if (self.sectionNameKeyPath)
        return self.fetchedObjects[indexPath.section][indexPath.item];

    NSAssert(indexPath.section == 0,
             @"Relation is not grouped into sections. Can't access object in section %ld.",
             (long)indexPath.section);

    return self.fetchedObjects[indexPath.item];
}

#pragma mark -

- (NSArray *)fetchedObjects {
    NSArray *objects = [self.objects filteredArrayUsingPredicate:[self predicate]];
    objects = [objects sortedArrayUsingDescriptors:[self sortDescriptors]];
    objects = [objects subarrayWithRange:NSMakeRange(self.offset, self.limit)];
    if (self.select) {
        objects = [objects map:^id(id obj) {
            NSMutableDictionary *properties = [NSMutableDictionary new];
            for (NSString *keyPath in self.select) {
                properties[keyPath] = [obj valueForKeyPath:keyPath];
            }
            return [properties copy];
        }];
    }
    if (self.sectionNameKeyPath) {
        objects = [[self class] sectionObjects:objects byKeyPath:self.sectionNameKeyPath];
    }
    return objects;
}

- (NSPredicate *)predicate {
    return [NSCompoundPredicate andPredicateWithSubpredicates:self.where];
}

- (NSArray *)sortDescriptors {
    return self.order;
}

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p; where: %@; order: %@; limit: %lu; offset: %lu>", [self class], self, self.where, self.order, (unsigned long)self.limit, (unsigned long)self.offset];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    typeof(self) copy = [(ObjectiveRelation *)[[self class] alloc] initWithObjects:self.objects];
    if (copy) {
        copy.where = [self.where copyWithZone:zone];
        copy.order = [self.order copyWithZone:zone];
        copy.limit = self.limit;
        copy.offset = self.offset;
    }
    return copy;
}

#pragma mark - NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)len {
    return [self.fetchedObjects countByEnumeratingWithState:state objects:buffer count:len];
}

#pragma mark - Private

- (NSPredicate *)predicateFromDictionary:(NSDictionary *)dict {
    NSArray *subpredicates = [dict map:^(id key, id value) {
        return [NSPredicate predicateWithFormat:@"%K = %@", key, value];
    }];

    return [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
}

- (NSPredicate *)predicateFromObject:(id)condition {
    return [self predicateFromObject:condition arguments:NULL];
}

- (NSPredicate *)predicateFromObject:(id)condition arguments:(va_list)arguments {
    if ([condition isKindOfClass:[NSPredicate class]])
        return condition;

    if ([condition isKindOfClass:[NSString class]])
        return [NSPredicate predicateWithFormat:condition arguments:arguments];

    if ([condition isKindOfClass:[NSDictionary class]])
        return [self predicateFromDictionary:condition];

    return [NSPredicate predicateWithBlock:condition];
}

- (NSSortDescriptor *)sortDescriptorFromDictionary:(NSDictionary *)dict {
    BOOL isAscending = ![[dict.allValues.first uppercaseString] isEqualToString:@"DESC"];
    return [NSSortDescriptor sortDescriptorWithKey:dict.allKeys.first ascending:isAscending];
}

- (NSSortDescriptor *)sortDescriptorFromString:(NSString *)order {
    NSArray *components = [order split];

    NSString *key = [components firstObject];
    NSString *value = [components count] > 1 ? components[1] : @"ASC";

    return [self sortDescriptorFromDictionary:@{key: value}];
}

- (NSSortDescriptor *)sortDescriptorFromObject:(id)order {
    if ([order isKindOfClass:[NSSortDescriptor class]])
        return order;

    if ([order isKindOfClass:[NSString class]])
        return [self sortDescriptorFromString:order];

    if ([order isKindOfClass:[NSDictionary class]])
        return [self sortDescriptorFromDictionary:order];

    return nil;
}

- (NSArray *)sortDescriptorsFromObject:(id)order {
    if ([order isKindOfClass:[NSString class]])
        order = [order componentsSeparatedByString:@","];

    if ([order isKindOfClass:[NSArray class]])
        return [order map:^id (id object) {
            return [self sortDescriptorFromObject:object];
        }];

    return @[[self sortDescriptorFromObject:order]];
}

@end