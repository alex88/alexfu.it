---
title: Varnish and MaxCdn not caching, how to solve it
date: 2012-08-23 15:05:06
priority: 0.9
changefreq: daily
tags:
- varnish
- cdn
- maxcdn
categories:
- Tips
---

At work we've started using [MaxCDN](http://www.maxcdn.com/){:target='_blank'} service because they're offering 1TB of data transfer for free (nice offer tbh) for serving images. The problem was that after one week of usage there was no cache hit, all requests was still going straight to our servers.

READMORE

After some investigation I've found that sending a Cache-Control header makes that request not cacheable by their servers, to solve this you've to add these lines to your Varnish config:

``` perl
sub vcl_deliver {
	remove resp.http.Cache-Control;
}
```

and after that your requests should be cached, to check, use curl in this way:

``` bash
curl -I your_url_here
```

and you should see this header: X-Cache: HIT after a few requests that means that the file is in cache.