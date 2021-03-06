/*
 Copyright (c) 2010 Mike Chambers
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "WoWTCGUtilityAppDelegate.h"
#import "Card.h"
#import "Rarity.h"
#import "WoWTCGDataStore.h"
#import "MenuTagConstants.h"
#import "UserDefaultsConstants.h"
#import "CardURLScheme.h"

#define MIN_WINDOW_WIDTH 400
#define MIN_WINDOW_HEIGHT 380

#define DECK_EXTENSION @"deck"
#define SEARCH_EXTENSION @"search"

@implementation WoWTCGUtilityAppDelegate

@synthesize window;
@synthesize dataStore;
@synthesize cardTable;
@synthesize cardView;
@synthesize searchField;
@synthesize filteredCards;
@synthesize cardOutlineView;
@synthesize addOutlineButton;
@synthesize searchSheet;
@synthesize preferencesWindow;
@synthesize appName;
@synthesize searchKeys;
@synthesize blocksWindow;

#define CARDS_DATA_TYPE @"CARDS_DATA_TYPE"

-(void)dealloc
{
	[blocksWindow release];
	[searchKeys release];
	[appName release];
	[preferencesWindow release];
	[searchSheet release];
	[addOutlineButton release];
	[cardOutlineView release];
	[filteredCards release];
	[searchField release];
	[dataStore release];
	[cardTable release];
	[cardView release];
	[window release];
	[super dealloc];
}

/*************** initialization APIS **********************/

-(id)init
{
	[super init];
	
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *appDefaults = [NSMutableDictionary
								 dictionaryWithObject:@"YES" forKey:RUN_DELETE_SEARCH_ALERT_KEY];
	[appDefaults setObject:@"YES" forKey:RUN_DELETE_CARD_ALERT_KEY];
	
    [defaults registerDefaults:appDefaults];	

	self.appName = [[NSProcessInfo processInfo] processName];
	
	[self initData];
		
	[self resetCardData];
		
	[self registerMyApp];
	
	return self;
}

-(void)awakeFromNib
{	
	NSSize minSize = { MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT };
	[window setContentMinSize:minSize];
	
	[cardTable registerForDraggedTypes: [NSArray arrayWithObject:CARDS_DATA_TYPE] ];
	[cardOutlineView registerForDraggedTypes: [NSArray arrayWithObject:CARDS_DATA_TYPE] ];	
	
	[self loadData:DECK_EXTENSION];
	[self loadData:SEARCH_EXTENSION];
	[cardOutlineView expandNodes];
}

/**************** custom URL scheme handler apis *****************/

- (void)registerMyApp
{
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSString *urlStr = [[[event paramDescriptorForKeyword:keyDirectObject] stringValue] stringByReplacingOccurrencesOfString:URL_SCHEME withString:@""];
	// Now we can parse the URL and perform whatever action is needed
	
	NSURL *url = [NSURL URLWithString:urlStr];	
	
	NSArray *tokens = [url.path componentsSeparatedByString:@"/"];

	if([tokens count] < 3)
	{
		return;
	}
	
	NSString *identifier = [tokens objectAtIndex:0];
	NSString *name = [tokens objectAtIndex:1];
	NSString *value = [tokens objectAtIndex:2];

	if([identifier compare:CARD_IDENTIFIER options:NSCaseInsensitiveSearch] != NSOrderedSame)
	{
		return;
	}
	
	if([name compare:CARD_ID_KEY options:NSCaseInsensitiveSearch] != NSOrderedSame )
	{
		return;
	}
	
	if(filteredCards != dataStore.cards)
	{
		//reset card data to all cards
		[self resetCardData];
		
		//reload the data in the card table
		[self reloadData];
		
		//tell the cardtable to redraw itself
		[cardTable redraw];
	}
	
	//need to loop to find since 10.5 doesnt support blocks and [NSArray indexOfObjectPassingTest];
	NSInteger index = NSNotFound;
	int searchIndex = [value intValue];
	NSArray *cards = dataStore.cards;
	int len = [cards count];
	
	Card *c;
	for(int i = 0; i < len; i++)
	{
		c = (Card *)[cards objectAtIndex:i];
		
		if(c.cardId == searchIndex)
		{
			index  = i;
			break;
		}
	}
	
	if(index == NSNotFound)
	{
		return;
	}

	[self selectCardTableRow:index];
	[cardTable scrollRowToVisible:index];
	
	[window makeFirstResponder:cardTable];
}


/**************  General App Lifecycle APIs *****************/

-(void)initData
{	
	NSString *path = [[[NSBundle mainBundle] resourcePath] 
					   stringByAppendingPathComponent:@"/assets/wow_tcg.data"];	
	
	NSDictionary *rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
	
	self.dataStore = [rootObject valueForKey:DATA_STORE_KEY];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return YES;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	[self importNode:[NSURL fileURLWithPath:filename]];
	
	return TRUE;
}

/***************** Data Persistence APIs ********************/

-(void)saveData:(NSString *)type
{
	NSMutableArray *children;
	
	if([type compare:SEARCH_EXTENSION] == NSOrderedSame)
	{
		children = cardOutlineView.searchNode.children;
	}
	else if([type compare:DECK_EXTENSION] == NSOrderedSame)
	{
		children = cardOutlineView.deckNode.children;
	}
	else
	{
		NSLog(@"saveData : type not recognized : %@", type);
		return;
	}
	
	NSString *path = [self pathForDataFile:type];
	
	NSMutableDictionary *rootObject = [NSMutableDictionary dictionary];
    
	[rootObject setValue:children forKey:type];
	[NSKeyedArchiver archiveRootObject: rootObject toFile: path];
}


-(void)loadData:(NSString *)type
{
	Node *rootNode;
	
	if([type compare:SEARCH_EXTENSION] == NSOrderedSame)
	{
		rootNode = cardOutlineView.searchNode;
	}
	else if([type compare:DECK_EXTENSION] == NSOrderedSame)
	{
		rootNode = cardOutlineView.deckNode;
	}
	else
	{
		NSLog(@"loadData : type not recognized : %@", type);
		return;
	}	
	
	NSString *path = [self pathForDataFile:type];
	
	NSFileManager *fMan = [NSFileManager defaultManager];
	if(![fMan fileExistsAtPath:path])
	{
		rootNode.children = [NSMutableArray arrayWithCapacity:0];
		return;
	}
	
	NSDictionary * rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:path]; 
	
	NSMutableArray *b = [rootObject valueForKey:type];
	
	rootNode.children = b;
}

- (NSString *) pathForDataFile:(NSString *)type
{   
	//todo : is there a better way to find this?
	NSString *folder = [NSString stringWithFormat:@"~/Library/Application Support/%@/", appName];
	folder = [folder stringByExpandingTildeInPath];
	
	NSFileManager *fMan = [NSFileManager defaultManager];
	if ([fMan fileExistsAtPath:folder] == NO)
	{
		[fMan createDirectoryAtPath: folder withIntermediateDirectories: TRUE
						 attributes: nil error:NULL];
	}
    
	NSString *extension = @"";
	
	if([type compare:DECK_EXTENSION] == NSOrderedSame)
	{
		extension = @"decks";
	}
	else if([type compare:SEARCH_EXTENSION] == NSOrderedSame)
	{
		extension = @"searches";
	}
	else
	{
		NSLog(@"Warning : pathForDataFile : unrecognized extension : %@", type);
	}
	
	NSString *fileName = [NSString stringWithFormat:extension, appName];
	
	return [folder stringByAppendingPathComponent: fileName];    
}

/********************* Drag and Drop Delegate *******************/

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{	
	NSArray *out = [filteredCards objectsAtIndexes:rowIndexes];
	
    // Copy the row numbers to the pasteboard.
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:out];
    [pboard declareTypes:[NSArray arrayWithObject:CARDS_DATA_TYPE] owner:self];
    [pboard setData:data forType:CARDS_DATA_TYPE];
    return YES;
}


- (NSDragOperation)outlineView:(NSOutlineView *)ov 
				  validateDrop:(id < NSDraggingInfo >)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
	Node *parent = (Node *)item;
	
	//only allow to drag to deck node right now
	if((parent == cardOutlineView.deckNode) ||
	   ([cardOutlineView parentForItem:parent] == cardOutlineView.deckNode))
	{
		return NSDragOperationCopy;
	}
	
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov 
		 acceptDrop:(id < NSDraggingInfo >)info item:(id)item childIndex:(NSInteger)index
{
	Node *parent = (Node *)item;
	
    NSPasteboard* pboard = [info draggingPasteboard];
	
    NSData* data = [pboard dataForType:CARDS_DATA_TYPE];
    
	NSMutableArray *cards = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
	Node *deck;
	if(parent == cardOutlineView.deckNode)
	{
		deck = [self createDeck:index];
	}
	else
	{
		deck = parent;
	}
	
	for(Card *card in cards)
	{
		[deck.children addObject:[NSNumber numberWithInt:card.cardId]];
	}

	[self saveData:DECK_EXTENSION];
	
	
	if([cardOutlineView selectedNode] == deck)
	{
		self.filteredCards = [self getCardsForIds:deck.children];
		[self refreshCardTableData];
	}
	
	return TRUE;
}

/********************* general Card TableView APIs *******************/

-(void)selectCardTableRow:(int)index
{
	int previousRow = cardTable.selectedRow;
	NSIndexSet *row = [NSIndexSet indexSetWithIndex:index];	
	[cardTable selectRowIndexes:row byExtendingSelection:FALSE];
	
	//note, we do the check here because if the index changes
	//then the table view will automatically call the change
	//delegate where we will set the cardView.card
	//this prevents it from being called twice.
	if(previousRow == index)
	{
		cardView.card = [filteredCards objectAtIndex:index];
	}
}

-(void)resetCardData
{
	self.filteredCards = [dataStore.cards mutableCopy];
}

-(void)refreshCardTableData
{
	[self reloadData];
	[cardTable redraw];
	
	if(filteredCards.count == 0)
	{
		cardView.card = nil;
		return;
	}
	
	[self selectCardTableRow:0];
}

-(void)reloadData
{
	[cardTable reloadData];
	[self updateTitle];
}

-(void)updateTitle
{
	int index = [cardOutlineView selectedRow];
	
	
	NSString *title;
	if(index == -1)
	{
		title = [self appName];
	}
	else
	{
		Node *node = [cardOutlineView itemAtRow:index];
	
		title = [NSString stringWithFormat:@"%@ : %@ (%i of %i Cards)", appName, node.label, 
				self.filteredCards.count, 
				self.dataStore.cards.count];
	}
	
	window.title = title;
}

-(NSString *)getNewNodeName:(Node *)parent withPrefix:(NSString *)prefix
{
	NSString *out;
		
	int len = parent.children.count;
	
	if(len == 0)
	{
		return prefix;
	}
	
	int count = 2;
	
	out = prefix;
	BOOL found = FALSE;
	while(TRUE)
	{
		for(Node *n in parent.children)
		{
			if([n.label compare:out] == NSOrderedSame)
			{
				found = true;
				break;
			}
		}
		
		if(found)
		{
			found = false;
			out = [prefix stringByAppendingFormat:@" %i", count];
			count++;
		}
		else
		{
			
			break;
		}
		
	}

	
	return out;
}

/************ NSTableView DataSource APIs **************/

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [filteredCards count];
}

-(id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{	
	NSString *identifier = [column identifier];
	Card *c = [filteredCards objectAtIndex:row];
	
	if([identifier compare:@"rarity"] == NSOrderedSame)
	{
		return [Rarity getRarityAbbreviationForType:(int)c.rarity];
	}
	else
	{
		return [c valueForKey:identifier];
	}
}

-(void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	NSArray *newDescriptors = [cardTable sortDescriptors];
	
	[filteredCards sortUsingDescriptors:newDescriptors];
	
	[self refreshCardTableData];
}

/************* NSOutlineView Delegate APIs *****************/

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[self updateOutlineViewSelection];
}

-(void)updateOutlineViewSelection
{
	
	int index = [cardOutlineView selectedRow];
	
	Node *node = [cardOutlineView itemAtRow:index];
	
	
	Node *parent = [cardOutlineView parentForItem:node];
	if(node == cardOutlineView.cardsNode)
	{
		[self resetCardData];
		[self refreshCardTableData];
	}
	else if(parent == cardOutlineView.searchNode)
	{
		[self filterCardsWithPredicate:((NSPredicate *)node.data)];
	}
	else if(parent == cardOutlineView.deckNode)
	{
		[self setCardsForDeck:node];
	}
}

-(void)setCardsForDeck:(Node *)node
{
	
	NSMutableArray *out = [self getCardsForIds:node.children];
	
	//note : we are not making a copy of this, since we dont reference
	//it / store it from anywhere else
	self.filteredCards = out;
	[self refreshCardTableData];
}

-(Card *)getCardForId:(int)cardId
{
	Card *c = [dataStore.cards objectAtIndex:cardId - 1];
	return c;
}

-(NSMutableArray *)getCardsForIds:(NSArray *)cards
{
	int count = [cards count];
	NSMutableArray *out = [NSMutableArray arrayWithCapacity:count];
	
	Card *c;
	for(NSNumber *cardId in cards)
	{
		c = [self getCardForId:[cardId intValue]];
		[out addObject:c];
	}
	
	return out;
}

-(void)tableViewSelectionDidChange:(NSNotification *)notification
{
	int index = [cardTable selectedRow];
	
	if(index < 0)
	{
		return;
	}

	Card *c = nil;
	if([filteredCards count] > 0)
	{
		c = [filteredCards objectAtIndex:index];
	}
	
	cardView.card = c;
}


/***************** Search APIs *******************/

-(IBAction)handleSearch:(NSSearchField *)sField
{
	NSString *searchString = [sField stringValue];
	
	if([searchString length] == 0)
	{
		[self resetCardData];
		[self refreshCardTableData];
		return;
	}
	
	if(!searchKeys)
	{
		self.searchKeys = [NSArray arrayWithObjects:
					 @"cardName",
					 @"series",
					 @"type",
					 @"className",
					 @"race",
					 @"professions",
					 @"talent",
					 @"faction",
					 @"keywords",
					 @"rules",
					 @"seriesType",
					 @"allyFaction",
					 @"talentRestrictions",
					 @"raceRestrictions",
					 @"professionRestrictions",
					 @"damageType",
					 @"reputationRestrictions",
					 nil
					 ];
	}
	
	int len = [searchKeys count];
	NSMutableArray *predicates = [NSMutableArray arrayWithCapacity:len];
	for(int i = 0; i < len; i++)
	{
		NSPredicate *p = [NSPredicate predicateWithFormat:@"%K contains[c] %@", 
											[searchKeys objectAtIndex:i], searchString];
		[predicates addObject:p];
	}
	
	NSPredicate *searchPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicates];
	[self filterCardsWithPredicate:searchPredicate];
	[cardOutlineView selectOutlineViewItem:cardOutlineView.cardsNode];
}

-(void)filterCardsWithPredicate:(NSPredicate *)predicate
{
	[self resetCardData];
	[filteredCards filterUsingPredicate:predicate];
	[self refreshCardTableData];
}

/************ General Outline View APIs **************/


//todo: move this to outline view class
-(void)deleteNode:(Node *)node
{
	//todo: update this
	Node *parent = [cardOutlineView parentForItem:node];
	
	int index = [parent.children indexOfObject:node];
	
	[parent.children removeObject:node];
	
	NSString *type;
	
	if(parent == cardOutlineView.searchNode)
	{
		type = SEARCH_EXTENSION;
	}
	else
	{
		type = DECK_EXTENSION;
	}
	
	[self saveData:type];
	
	[cardOutlineView reloadItem:parent reloadChildren:TRUE];
	
	
	//note: In most cases, the OutlineView will automatically
	//switch selection when we move an item. 
	//However, in some cases it will not. The first two if
	//statements below check for those.
	
	//if there are no more child nodes then set the selection
	//to the main cards node
	if(parent.children.count == 0)
	{
		[cardOutlineView selectOutlineViewItem:cardOutlineView.cardsNode];
	}
	else if(index == 0)
	{
		[cardOutlineView selectOutlineViewItem:[parent.children objectAtIndex:0]];
	}
	else
	{
		//otherwise, the controll will set the selection. We then just
		//need to update the cards
		[self updateOutlineViewSelection];
	}
}

/**************** Outline View Data Source APIs **********************/


- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	
	//used in case item == nil //i.e. root
	int out = 3;
	if(item == cardOutlineView.searchNode || item == cardOutlineView.deckNode)
	{
		out = [((Node*)item).children count];
	}
	
    return out;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if(item == cardOutlineView.deckNode || item == cardOutlineView.searchNode)
	{
		return TRUE;
	}
	else
	{
		return FALSE;
	}
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	Node *out;
	if(item == nil)
	{
		switch(index)
		{
			case CARD_NODE_INDEX:
			{
				out = cardOutlineView.cardsNode;
				break;
			}
			case SEARCH_NODE_INDEX:
			{
				out = cardOutlineView.searchNode;
				break;
			}
			case DECK_NODE_INDEX:
			{
				out = cardOutlineView.deckNode;
				break;
			}
		}
	}
	else
	{
		out = [((Node*)item).children objectAtIndex:index];
	}
	
	return out;
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return ((Node *)item).label;
}

- (void)outlineView:(NSOutlineView *)ov setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *s = ((NSString *) object);
	
	if(s.length < 1)
	{
		return;
	}
	
	Node *node = (Node *)item;
	
	node.label = s;
	
	Node *parent = [cardOutlineView parentForItem:node];
	
	NSString *type;
	
	if(parent == cardOutlineView.searchNode)
	{
		type = SEARCH_EXTENSION;
	}
	else
	{
		type = DECK_EXTENSION;
	}
	
	[self saveData:type];
}

/***************** outline view delegate APIs ********************/

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	BOOL out = FALSE;
	if(item == cardOutlineView.deckNode || item == cardOutlineView.searchNode || item == cardOutlineView.cardsNode)
	{
		out = TRUE;
	}

	return out;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return !(item == cardOutlineView.deckNode || item == cardOutlineView.searchNode);
}

/************ IBAction Handlers ****************/


-(IBAction)handleCreateSearchClick:(id)sender
{
	NSString *nodeName = [self getNewNodeName:cardOutlineView.searchNode withPrefix:@"untitled search"];
	Node *n = [[[Node alloc] initWithLabel:nodeName] autorelease];
	[self showSavedSearchSheet:n];
}

-(IBAction)handleCreateDeck:(id)sender
{
	[self createDeck:-1];
	[self saveData:DECK_EXTENSION];
}

-(Node *)createDeck:(NSUInteger) index
{
	NSString *nodeName = [self getNewNodeName:cardOutlineView.deckNode withPrefix:@"untitled deck"];
	Node *node = [[[Node alloc] initWithLabel:nodeName] autorelease];
	node.children = [NSMutableArray arrayWithCapacity:1];
	
	if(index == -1)
	{
		index = [cardOutlineView.deckNode.children count];
	}

	[cardOutlineView.deckNode.children insertObject:node atIndex: index];
	
	[cardOutlineView refreshNode:cardOutlineView.deckNode];
	
	return node;
}

-(IBAction)handleEditSearchClick:(id)sender
{
	Node *node = [cardOutlineView selectedNode];
	
	if([cardOutlineView parentForItem:node] != cardOutlineView.searchNode)
	{
		//we should never get here
		
		NSLog(@"ERROR : onEditSearchClick: Edit Search Context Menu selected for non search node");
		return;
	}
	
	[self showSavedSearchSheet:node];
}

-(void)deleteSelectedOutlineViewNode
{
	Node *node = [cardOutlineView selectedNode];
	Node *parent = [cardOutlineView parentForItem:node];
	if(parent != cardOutlineView.deckNode && parent != cardOutlineView.searchNode)
	{
		return;
	}
	
	BOOL runAlert = [[NSUserDefaults standardUserDefaults] boolForKey:RUN_DELETE_SEARCH_ALERT_KEY];
	
	if(!runAlert)
	{
		[self deleteNode:node];
		return;
	}
	
	NSString *type = (parent == cardOutlineView.deckNode)?@"Deck":@"Search";
	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"Are you sure you want to delete the %@ named \"%@\"?", type, node.label] 
									 defaultButton:@"OK" 
								   alternateButton:@"Cancel" 
									   otherButton:nil 
						 informativeTextWithFormat:@"This action cannot be undone."];
	
	alert.alertStyle = NSWarningAlertStyle;
	[alert setShowsSuppressionButton:TRUE];
	
	NSInteger result = [alert runModal];
	
	if(result == NSAlertDefaultReturn)
	{
		[self deleteNode:node];
	}
	
	if([[alert suppressionButton] state] == NSOnState)
	{
		[[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:RUN_DELETE_SEARCH_ALERT_KEY];
	}
}

-(IBAction)handleDeleteNodeMenu:(id)sender
{	
	[self deleteSelectedOutlineViewNode];
}

-(IBAction)handleAlwaysOnTopMenu:(id)sender
{
	NSMenuItem *item = (NSMenuItem *)sender;
	
	BOOL alwaysOnTop = !item.state;
	item.state = alwaysOnTop;
	
	if(alwaysOnTop)
	{
		[[self window] setLevel:NSFloatingWindowLevel];
	}
	else
	{
		[[self window] setLevel:NSNormalWindowLevel];
	}
}

-(IBAction)handleRenameItemMenu:(id)sender
{
	[cardOutlineView setSelectedItemToEdit];
}

-(IBAction)handlePreferencesMenu:(id)sender
{
	if(!preferencesWindow)
	{
		self.preferencesWindow = [[PreferencesWindowController alloc] init];
	}
	
	[preferencesWindow showWindow:self];
	[preferencesWindow.window center];
}

-(IBAction)handleLogBugMenu:(id)sender
{
	NSURL *url = [NSURL URLWithString:@"http://github.com/mikechambers/WoWTCGUtility/issues"];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

-(IBAction)handleSendFeedbackMenu:(id)sender
{
	NSString *to = @"mikechambers@gmail.com";
	NSString *subject = [NSString stringWithFormat:@"%@ Feedback", appName];
	NSString *encodedSubject = [NSString stringWithFormat:@"SUBJECT=%@", [subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSString *encodedTo = [to stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *encodedURLString = [NSString stringWithFormat:@"mailto:%@?%@", encodedTo, encodedSubject];
	NSURL *mailtoURL = [NSURL URLWithString:encodedURLString];
	[[NSWorkspace sharedWorkspace] openURL:mailtoURL];	
}

-(IBAction)handleQuickSearchMenu:(id)sender
{
	[window makeFirstResponder:searchField];
}

-(IBAction)handleCoreSetPDFMenu:(id)sender
{
	if(!blocksWindow)
	{
		NSString *path = [[[NSBundle mainBundle] resourcePath] 
					  stringByAppendingPathComponent:@"/assets/blocks.pdf"];	
		self.blocksWindow = [[PDFViewWindowController alloc] initWithPath:path];
		[blocksWindow release];
	}
		
	[blocksWindow showWindow:self];
	[blocksWindow.window center];
}

-(NSURL *)openExportPanel:(NSString *)extension
{
	Node *node = [cardOutlineView selectedNode];
	
	NSSavePanel *panel = [NSSavePanel savePanel];
	panel.prompt = @"Export";
	
	if([extension compare:DECK_EXTENSION] == NSOrderedSame)
	{
		panel.title = @"Export Deck";
	}
	else if([extension compare:SEARCH_EXTENSION] == NSOrderedSame)
	{
		panel.title = @"Export Search";	
	}
	else
	{
		NSLog(@"openExportPanel : Extension not recognized : %@", extension);
		return nil;
	}

	panel.allowedFileTypes = [NSArray arrayWithObject:extension];
	
	if([panel respondsToSelector:@selector(setNameFieldStringValue:)])
	{
		[panel setNameFieldStringValue:[NSString stringWithFormat:@"%@.%@", node.label, extension]];
	}
	
	int result = [panel runModal];
	
	if(result == NSCancelButton)
	{
		return nil;
	}
	
	NSURL *fileURL = [panel URL];
	return fileURL;
}

-(NSURL *)openImportPanel:(NSString *)extension
{
	NSArray *types = [NSArray arrayWithObject:extension];
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	//panel.allowedFileTypes = types;
	panel.prompt = @"Import";
	
	if([extension compare:DECK_EXTENSION] == NSOrderedSame)
	{
		panel.title = @"Select Deck";
	}
	else if([extension compare:SEARCH_EXTENSION] == NSOrderedSame)
	{
		panel.title = @"Select Search";	
	}
	else
	{
		NSLog(@"openExportPanel : Extension not recognized : %@", extension);
		return nil;
	}	
	
	//int result = [panel runModal];
	int result = [panel runModalForTypes:types];
		
	if(result == NSCancelButton)
	{
		return nil;
	}

	NSURL *fileURL = [panel URL];
	return fileURL;
}

-(IBAction)handleImportDeckMenu:(id)sender
{
	NSURL *fileURL = [self openImportPanel:DECK_EXTENSION];
	
	[self importNode:fileURL];
}

-(IBAction)handleImportSearchMenu:(id)sender
{
	NSURL *fileURL = [self openImportPanel:SEARCH_EXTENSION];
	
	[self importNode:fileURL];
}

-(void)importNode:(NSURL *)fileURL
{
	if(!fileURL)
	{
		return;
	}
	
	NSDictionary *rootObject;
	Node *node = nil;
	Node *parent;
	NSString *extension;
	@try
	{
		rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:fileURL.path];
		
		//figure out which type of node we are importing
		node = [rootObject valueForKey:DECK_EXTENSION];
		
		
		if(node != nil)
		{
			parent  = cardOutlineView.deckNode;
			extension = DECK_EXTENSION;
		}
		else
		{
			node = [rootObject valueForKey:SEARCH_EXTENSION];
			parent = cardOutlineView.searchNode;
			extension = SEARCH_EXTENSION;
		}		
	}
	@catch (NSException *exception)
	{
	}

	if(node == nil)
	{		
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"Could not import deck."];
		[alert setInformativeText:@"Make sure you selected the correct deck file."];
		[alert setAlertStyle:NSInformationalAlertStyle];		
		[alert runModal];
		[alert release];
		return;
	}
	
	[parent.children addObject:node];
	[cardOutlineView refreshNode:parent];
	
	[self saveData:extension];
}

-(void)exportNode:(NSURL *)fileURL forExtension:(NSString *)extension
{
	if(!fileURL)
	{
		return;
	}
	
	Node *node = [cardOutlineView selectedNode];
	
	NSMutableDictionary *rootObject = [NSMutableDictionary dictionary];
    
	[rootObject setValue:node forKey:extension];
	[NSKeyedArchiver archiveRootObject: rootObject toFile: fileURL.path];
}

-(IBAction)handleExportDeckMenu:(id)sender
{
	NSURL *fileURL = [self openExportPanel:DECK_EXTENSION];

	[self exportNode:fileURL forExtension:DECK_EXTENSION];
}

-(IBAction)handleExportSearchMenu:(id)sender
{
	NSURL *fileURL = [self openExportPanel:SEARCH_EXTENSION];
	[self exportNode:fileURL forExtension:SEARCH_EXTENSION];
}

//delegate method for Export menu
- (void)menuWillOpen:(NSMenu *)menu
{
	[cardOutlineView updateMenuState:menu forItem:[cardOutlineView selectedNode]];
}

/****************** Search Sheet APIs ***********/


//delegate listener for SearchSheet
- (void)predicateNodeWasCreated:(Node *)predicateNode
{
	if([cardOutlineView rowForItem:predicateNode] == -1)
	{
		[cardOutlineView.searchNode.children addObject:predicateNode];
	}
	
	[cardOutlineView refreshNode:cardOutlineView.searchNode];
	
	[cardOutlineView selectOutlineViewItem:predicateNode];
	
	[self filterCardsWithPredicate:((NSPredicate *)predicateNode.data)];

	[self saveData:SEARCH_EXTENSION];
}

-(void)showSavedSearchSheet:(Node *)predicateNode
{
	if(searchSheet == nil)
	{
		self.searchSheet = [[[SearchSheetController alloc] init] autorelease];
		searchSheet.dataStore = dataStore;
		searchSheet.delegate = self;
	}
	
	[searchSheet showSheet:[self window] withPredicateNode:predicateNode];
}

- ( void )outlineViewDeleteKeyPressed:( NSOutlineView * ) view 
{
	[self deleteSelectedOutlineViewNode];
}

- ( void )tableViewDeleteKeyPressed:( NSTableView * ) view 
{
	Node *node = [cardOutlineView selectedNode];
	
	if([cardOutlineView parentForItem:node] != cardOutlineView.deckNode)
	{
		return;
	}	
	
	BOOL runAlert = [[NSUserDefaults standardUserDefaults] boolForKey:RUN_DELETE_CARD_ALERT_KEY];
	
	if(!runAlert)
	{
		[self deleteSelectedCardsFromTableView];
		return;
	}
	
	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"Are you sure you want to delete the selected cards from the Deck named \"%@\"?", node.label] 
									 defaultButton:@"OK" 
								   alternateButton:@"Cancel" 
									   otherButton:nil 
						 informativeTextWithFormat:@"This action cannot be undone."];
	
	alert.alertStyle = NSWarningAlertStyle;
	[alert setShowsSuppressionButton:TRUE];
	
	NSInteger result = [alert runModal];
	
	if(result == NSAlertDefaultReturn)
	{
		[self deleteSelectedCardsFromTableView];
	}
	
	if([[alert suppressionButton] state] == NSOnState)
	{
		[[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:RUN_DELETE_CARD_ALERT_KEY];
	}
}

-(void)deleteSelectedCardsFromTableView
{	
	NSIndexSet *rowIndexes = [cardTable selectedRowIndexes];
	
	Node *node = [cardOutlineView selectedNode];
	int index = rowIndexes.firstIndex;
	
	NSMutableArray *children = node.children;
	
	[children removeObjectsAtIndexes:rowIndexes];

	self.filteredCards = [self getCardsForIds:node.children];

	[self saveData:DECK_EXTENSION];
	[self refreshCardTableData];
	

	//note: In most cases, the OutlineView will automatically
	//switch selection when we move an item. 
	//However, in some cases it will not. The first two if
	//statements below check for those.
	
	//if there are no more child nodes then set the selection
	//to the main cards node
	
	
	if(children.count == 0)
	{
		return;
	}
	
	if(index == 0)
	{
		[cardTable selectTableViewIndex:0];
	}
	else
	{
		[cardTable selectTableViewIndex:index - 1];
		//otherwise, the controll will set the selection. We then just
		//need to update the cards
		//[self updateOutlineViewSelection];
	}	
}

/*********** menu delegate apis *********/

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	[cardOutlineView menuNeedsUpdate:menu];
}




@end
