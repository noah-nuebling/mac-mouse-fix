//
//  CoolTreeNode.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 12.07.24.
//

#import <Cocoa/Cocoa.h>
#import "Foundation/Foundation.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Forward declare
///

@class TreeNode<U>;

///
/// Definitions
///

typedef NS_ENUM(NSInteger, MFTreeTraversal) {
    MFTreeTraversalDepthFirst = 1,
    MFTreeTraversalParents = 2,
    MFTreeTraversalSiblingsForward = 3,
    MFTreeTraversalSiblingsBackward = 4,
};

///
/// Enumerator
///

@interface TreeEnumerator<T> : NSEnumerator<TreeNode<T> *>

- (instancetype)initWithRootNode:(TreeNode<T> *)rootNode traversal:(MFTreeTraversal)traversal;

@end

///
/// NSTree Subclass
///

@interface TreeNode<T> : NSTreeNode

/// Add lightweight generics to existing methods.
@property (nullable, readonly, strong) T representedObject;
@property (nullable, readonly, copy) NSArray<TreeNode<T> *> *childNodes;
//@property (readonly, strong) NSMutableArray<TreeNode<T> *> *mutableChildNodes; /// This gives compiler warnings for some reason
@property (nullable, readonly, weak) TreeNode<T> *parentNode;

/// Tree Factories
+ (TreeNode<T> *)treeWithKVCObject:(T)kvcObject childrenKey:(NSString *)childrenKey;

/// Convenience methods
- (NSArray <TreeNode<T> *> *)siblings;
- (TreeNode<T> *_Nullable)nextSibling;
- (TreeNode<T> *_Nullable)previousSibling;
- (NSInteger)indexOfSelfInParent;

/// Enumeration
- (TreeEnumerator<T> *)parentEnumerator;
- (TreeEnumerator<T> *)depthFirstEnumerator;
- (TreeEnumerator<T> *)siblingEnumeratorForward;
- (TreeEnumerator<T> *)siblingEnumeratorBackward;

/// Other
- (NSString *)description;

@end




NS_ASSUME_NONNULL_END
