#!/usr/bin/perl
use warnings;

use URI;
use HTML::Parser;
use WWW::Mechanize;
use HTML::Tree;

use Scalar::Util;
use Data::Dumper;

my ($total, $query) = @ARGV;

if (!Scalar::Util::looks_like_number $total || !$query) {
    print "Usage: $0 count query\n";
    die;
}

my $url = 'http://www.google.com/search?q='.$query;

# FIXME: Google changes its html (and search results) based on the
#        user agent. So, right now this hack only works with a few.
my $user_agent;
##$user_agent = 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)';
#$user_agent = 'Mozilla/5.0 (Windows; U; Windows NT 5.0; en-US; rv:1.4b) Gecko/20030516 Mozilla Firebird/0.6';
##$user_agent = 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/85 (KHTML, like Gecko) Safari/85';
#$user_agent = 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.4a) Gecko/20030401';
#$user_agent = 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030624';
##$user_agent = 'Mozilla/5.0 (compatible; Konqueror/3; Linux)';

my $M = WWW::Mechanize->new(onwarn => undef, onerror => undef, agent => ($user_agent or undef));

# make query
$M->get($url);

# start counting results
my ($page, $count) = (1, 0);
do {
    my $tree = HTML::Tree->new();
    $tree->parse($M->content());

    my @items = $tree->look_down(_tag => 'h3');

    for my $item (@items) {
        my $anchor = $item->look_down(_tag => 'a');
        next if not $anchor;

        my $href = $anchor->attr('href');
        next if substr($href, 0, 5) ne '/url?';

        my $uri = URI->new($href);
        my %q = $uri->query_form();

        print $q{'q'}."\n";

        $count += 1;
        last if !($count < $total);
    }

    $page += 1;
    $_ = $M->follow_link(text => "$page");
} while ($count < $total and $_);

exit $count? 0 : 1;
