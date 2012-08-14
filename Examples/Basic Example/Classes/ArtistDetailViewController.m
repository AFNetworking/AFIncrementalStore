// ArtistDetailViewController.m
//
// Copyright (c) 2012 Mattt Thompson (http://mattt.me)
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
#import "ArtistDetailViewController.h"

#import "Artist.h"

@implementation ArtistDetailViewController {
    Artist *_artist;
    NSArray *_orderedSongs;
    UILabel *_descriptionLabel;
    
    NSFetchedResultsController *_fetchedResultsController;
}

- (id)initWithArtist:(Artist *)artist {
    self = [super initWithStyle:UITableViewStylePlain];
    if (!self) {
        return nil;
    }
    
    _artist = artist;
    _orderedSongs = [_artist.songs allObjects];
    
    [_artist.managedObjectContext refreshObject:_artist mergeChanges:NO];
    
    [_artist addObserver:self forKeyPath:@"artistDescription" options:0 context:nil];
    [_artist addObserver:self forKeyPath:@"songs" options:0 context:nil];
    
    return self;
}

- (void)dealloc {
    [_artist removeObserver:self forKeyPath:@"artistDescription"];
    [_artist removeObserver:self forKeyPath:@"songs"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([object isEqual:_artist]) {
        if ([keyPath isEqualToString:@"artistDescription"]) {
            _descriptionLabel.text = _artist.artistDescription;
        } else if ([keyPath isEqualToString:@"songs"]) {
            _orderedSongs = [_artist.songs allObjects];
            [self.tableView reloadData];
        }
    }
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = _artist.name;
    
    UIView *tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.tableView.frame.size.width, 80.0f)];
    _descriptionLabel = [[UILabel alloc] initWithFrame:CGRectInset(tableHeaderView.bounds, 10.0f, 10.0f)];
    _descriptionLabel.numberOfLines = 0;
    _descriptionLabel.font = [UIFont systemFontOfSize:11.0f];
    _descriptionLabel.text = _artist.artistDescription;
    [tableHeaderView addSubview:_descriptionLabel];
    self.tableView.tableHeaderView = tableHeaderView;
    
    [self.tableView reloadData];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:_fetchedResultsController action:@selector(performFetch:)];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_orderedSongs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    NSManagedObject *managedObject = [_orderedSongs objectAtIndex:indexPath.row];
    cell.textLabel.text = [managedObject valueForKey:@"title"];
    cell.detailTextLabel.text = [managedObject valueForKeyPath:@"artist.name"];
    
    return cell;
}

@end
