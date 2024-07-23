//
//  TreeNode.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 12.07.24.
//

#import "NSString+Additions.h"
#import "TreeNode.h"

///
/// NSTree subclass
///

@implementation TreeNode

@dynamic representedObject, childNodes, mutableChildNodes, parentNode;

- (NSArray <TreeNode *> *)siblings {
    return self.parentNode.childNodes;
}

- (TreeNode *_Nullable)nextSibling {
    NSInteger siblingIndex = self.indexOfSelfInParent + 1;
    BOOL siblingExists = (0 <= siblingIndex) && (siblingIndex <= self.siblings.count - 1);
    if (siblingExists) {
        return self.siblings[siblingIndex];
    }
    return nil;
}
- (TreeNode *_Nullable)previousSibling {
    NSInteger siblingIndex = self.indexOfSelfInParent - 1;
    BOOL siblingExists = (0 <= siblingIndex) && (siblingIndex <= self.siblings.count - 1);
    if (siblingExists) {
        return self.siblings[siblingIndex];
    }
    return nil;
}

- (NSInteger)indexOfSelfInParent {
    return [self.indexPath indexAtPosition: self.indexPath.length - 1];
}

- (NSString *)description {
    
    NSInteger indentDepth = 4;
    
    NSString *result = [self.representedObject description];
    
    NSMutableArray *childStringArray = [NSMutableArray array];
    
    for (TreeNode *child in self.childNodes) {
        NSString *childDescription = [child description];
        childDescription = [childDescription stringByAddingIndent:indentDepth];
        childDescription = [[@"- " stringByAppendingString:[childDescription substringFromIndex:indentDepth]] stringByPrependingWhitespace:indentDepth-2]; /// Add a bullet at the start of each child.
        [childStringArray addObject:childDescription];
    }
    NSString *childString = [childStringArray componentsJoinedByString:@"\n"];
    
    if (childString != nil && childString.length > 0) {
        result = [NSString stringWithFormat:@"%@\n%@", result, childString];
    }
    
    return result;
}

- (TreeEnumerator *)depthFirstEnumerator {
    return [[TreeEnumerator alloc] initWithRootNode:self traversal:MFTreeTraversalDepthFirst];
}

- (TreeEnumerator *)parentEnumerator {
    return [[TreeEnumerator alloc] initWithRootNode:self traversal:MFTreeTraversalParents];
}

- (TreeEnumerator *)siblingEnumeratorForward {
    return [[TreeEnumerator alloc] initWithRootNode:self traversal:MFTreeTraversalSiblingsForward];
}

- (TreeEnumerator *)siblingEnumeratorBackward {
    return [[TreeEnumerator alloc] initWithRootNode:self traversal:MFTreeTraversalSiblingsBackward];
}


@end

///
/// TreeEnumerator
///

@implementation TreeEnumerator {
    TreeNode *_rootNode;
    TreeNode *_currentNode;
    NSInteger _lastVisitedChildIndex;
    MFTreeTraversal _traversal;
}

- (instancetype)initWithRootNode:(TreeNode *)rootNode traversal:(MFTreeTraversal)traversal {
    self = [super init];
    if (self) {
        
        _traversal = traversal;
        
        if (traversal == MFTreeTraversalSiblingsForward || traversal == MFTreeTraversalSiblingsBackward) {
            
            _currentNode = rootNode;
            
        } else if (traversal == MFTreeTraversalParents) {
            
            _currentNode = rootNode;
            
        } else if (traversal == MFTreeTraversalDepthFirst) {
            
            _rootNode = rootNode;
            _currentNode = rootNode;
            _lastVisitedChildIndex = -1;
            
        } else {
            NSLog(@"Error: Unknown tree traversal type.");
            assert(false);
            return nil;
        }
    }
    return self;
}

- (TreeNode *)nextObject {
    
    
    if (_traversal == MFTreeTraversalParents) {
        
        _currentNode = _currentNode.parentNode;
        
    } else if (_traversal == MFTreeTraversalSiblingsForward) {
        
        _currentNode = _currentNode.nextSibling;
        
    } else if (_traversal == MFTreeTraversalSiblingsBackward) {
        
        _currentNode = _currentNode.previousSibling;
        
    } else if (_traversal == MFTreeTraversalDepthFirst) {
        
        [self goToNextObjectDepthFirst];
        
    } else {
        assert(false);
        return nil;
    }
    
    return _currentNode;
}


///
/// Depth first
///

- (void)goToNextObjectDepthFirst {
    
    /// I kinda forgot what depth first traversal is, but I think this implements what can be seen as DFS in this article: https://builtin.com/software-engineering-perspectives/tree-traversal
    
    /// Find first unvisited child
    NSInteger indexOfFirstUnvisitedChild = _lastVisitedChildIndex + 1;
    
    BOOL unvisitedChildExists = indexOfFirstUnvisitedChild < _currentNode.childNodes.count;
    if (unvisitedChildExists) {
        
        /// Go to first leaf inside unvisited child
        _currentNode = [self firstLeafInside:_currentNode.childNodes[indexOfFirstUnvisitedChild]];
        _lastVisitedChildIndex = -1; /// This signals that we haven't visited any children of the new `_currentNode`, but I don't think we have to do this, since its a leaf and doesn't have children anyways.
        
    } else {
        
        /// There are no unvisited children
        ///     -> Go to parent
        
        /// End enumeration
        ///  Short of going to the parent of the `_rootNode` - which we don't want
        if ([_currentNode isEqual:_rootNode]) {
            _currentNode = nil;
            return;
        }
        
        /// Actually go to parent
        _lastVisitedChildIndex = _currentNode.indexOfSelfInParent;
        _currentNode = _currentNode.parentNode;
        
        /// Actually, if parent (which is now  in`_currentNode`) has an unvisited child, go there first
        indexOfFirstUnvisitedChild = _lastVisitedChildIndex + 1;
        unvisitedChildExists = indexOfFirstUnvisitedChild < _currentNode.childNodes.count;
        if (unvisitedChildExists) {
            _currentNode = [self firstLeafInside:_currentNode.childNodes[indexOfFirstUnvisitedChild]];
            _lastVisitedChildIndex = -1;
        } else {
            /// In this case we actually go to the parent, and don't override `_currentNode` with some leaf
        }
    }
    
}

- (TreeNode *)firstLeafInside:(TreeNode *)node {
    
    if (node.childNodes.count == 0) {
        return node;
    }
    TreeNode *firstChild = node.childNodes.firstObject;
    TreeNode *firstLeaf = [self firstLeafInside:firstChild];
    return firstLeaf;
}

@end
