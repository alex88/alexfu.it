---
date: 2013-10-22 10:30:00
title: Symfony benchmark using HHVM
priority: 0.9
changefreq: daily
categories:
- Symfony
- Tips
tags:
- symfony
- hhvm
- benchmark
- facebook
- nginx
- php-fpm
---

Yesterday [Asm89](https://twitter.com/iam_asm89/){:target='_blank'} blogged about a custom version of symfony edited to run on Facebook's [HHVM](http://www.hiphop-php.com/){:target='_blank'}. I've followed his great blog post (you can read it [here](http://labs.qandidate.com/blog/2013/10/21/running-symfony-standard-on-hhvm/){:target='_blank'}) in how to setup HHVM to run the Symfony standard web application.

After that I've tested the performances compared to a nginx + php-fpm configuration and I wanted to share the results here.

READMORE

> N.B. This is a benchmark of the symfony standard application just to have a starting point on how much the difference can be YMMV

##### Test setup

I've run the tests on a vagrant VM on a i5 3750k with assigned 4 cores. The box was running Ubuntu 12.04 64-bit. I've installed both HHVM and nginx + php-fpm on the same box running on different ports. Nginx and php-fpm was tuned following [this](http://rtcamp.com/tutorials/php/fpm-sysctl-tweaking/){:target='_blank'} article and php-fpm with `max_children = 10`.

#### Tests

I've used [apache bench](http://httpd.apache.org/docs/2.2/programs/ab.html){:target='_blank'} to test the default symfony webapp demo page using the production environment, all tests used 2000 requests with 1, 10, 50, 100 concurrent clients.

This is what I've got, enjoy.

<table class="table table-striped">
  <thead>
    <tr>
      <th>Server - concurrency</th>
      <th>Requests per second</th>
      <th>Time per request (ms)</th>
      <th>50% req served within (ms)</th>
      <th>90% req served within (ms)</th>
      <th>99% req served within (ms)</th>
      <th>100% req served within (ms)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Nginx - 1 user</td>
      <td>25.48</td>
      <td>39.245</td>
      <td>39</td>
      <td>40</td>
      <td>41</td>
      <td>52</td>
    </tr>
    <tr>
      <td>Nginx (APC) - 1 user</td>
      <td>93.74</td>
      <td>10.668</td>
      <td>10</td>
      <td>11</td>
      <td>14</td>
      <td>17</td>
    </tr>
    <tr>
      <td>Nginx 5.5 (OPcache) - 1 user</td>
      <td>135.01</td>
      <td>7.407</td>
      <td>7</td>
      <td>8</td>
      <td>10</td>
      <td>21</td>
    </tr>
    <tr>
      <td>HHVM - 1 user</td>
      <td>105.79</td>
      <td>9.453</td>
      <td>9</td>
      <td>10</td>
      <td>13</td>
      <td>16</td>
    </tr>
    <tr>
      <td>Nginx - 10 user</td>
      <td>78.90</td>
      <td>126.736</td>
      <td>125</td>
      <td>177</td>
      <td>220</td>
      <td>334</td>
    </tr>
    <tr>
      <td>Nginx (APC) - 10 user</td>
      <td>259.74</td>
      <td>38.492</td>
      <td>37</td>
      <td>56</td>
      <td>79</td>
      <td>106</td>
    </tr>
    <tr>
      <td>Nginx 5.5 (OPcache) - 10 user</td>
      <td>399.23</td>
      <td>25.048</td>
      <td>24</td>
      <td>32</td>
      <td>42</td>
      <td>66</td>
    </tr>
    <tr>
      <td>HHVM - 10 user</td>
      <td>362.79</td>
      <td>27.564</td>
      <td>24</td>
      <td>47</td>
      <td>81</td>
      <td>144</td>
    </tr>
    <tr>
      <td>Nginx - 50 user</td>
      <td>73.74</td>
      <td>678.035</td>
      <td>665</td>
      <td>869</td>
      <td>1079</td>
      <td>1249</td>
    </tr>
    <tr>
      <td>Nginx (APC) - 50 user</td>
      <td>239.62</td>
      <td>208.661</td>
      <td>190</td>
      <td>275</td>
      <td>371</td>
      <td>586</td>
    </tr>
    <tr>
      <td>Nginx 5.5 (OPcache) - 50 user</td>
      <td>378.44</td>
      <td>132.120</td>
      <td>131</td>
      <td>146</td>
      <td>163</td>
      <td>182</td>
    </tr>
    <tr>
      <td>HHVM - 50 user</td>
      <td>369.74</td>
      <td>135.231</td>
      <td>126</td>
      <td>203</td>
      <td>319</td>
      <td>898</td>
    </tr>
    <tr>
      <td>Nginx - 100 user</td>
      <td>76.66</td>
      <td>1304.518</td>
      <td>1292</td>
      <td>1481</td>
      <td>1714</td>
      <td>1980</td>
    </tr>
    <tr>
      <td>Nginx (APC) - 50 user</td>
      <td>278.30</td>
      <td>359.326</td>
      <td>357</td>
      <td>384</td>
      <td>408</td>
      <td>455</td>
    </tr>
    <tr>
      <td>Nginx 5.5 (OPcache) - 100 user</td>
      <td>385.82</td>
      <td>259.185</td>
      <td>254</td>
      <td>292</td>
      <td>316</td>
      <td>336</td>
    </tr>
    <tr>
      <td>HHVM - 100 user</td>
      <td>364.71</td>
      <td>274.191</td>
      <td>269</td>
      <td>332</td>
      <td>389</td>
      <td>494</td>
    </tr>
  </tbody>
</table>

As you can see HHVM is about 4 times faster then php so as soon it gets stable and more usable you should really consider looking into it.

As I've already said, this is just Symfony standard application, you can get worse or better results using HHVM on our own project, but for such a big performance improvement, it should be worth the work :)

**Update:** I've added the tests with APC enabled, it increased a lot compared to the plain PHP version, but still HHVM is faster.

**Update 2:** I've added also tests with PHP 5.5 using the Zend OPcache enabled, it seems they perform even better than HHVM! I've used both PHP and HHVM out of the box, without any config changes, if you think there is another test that I haven't done drop a comment and I'll try to run it!

### Complexity heads up!

This is just an hello world example, as pointed out on Twitter by [@chregu](https://twitter.com/chregu/status/392675452663640064){:target='_blank'} when more work has to be done by PHP, HHVM performs better than PHP 5.5 + OPcache.

As a simple test I've tried to run this function:

```php
<?php

function fib($n)
{
    if ($n <= 2)
        return 1;
    else
        return fib($n-1) + fib($n-2);
}

$n = 32;
printf("fib(%d) = %d\n", $n, fib($n, 2));
```

on both HHVM and PHP 5.5 + OPcache (using only 500 requests, too much to wait with just PHP), these are the results:

<table class="table table-striped">
  <thead>
    <tr>
      <th>Server - concurrency</th>
      <th>Requests per second</th>
      <th>Time per request (ms)</th>
      <th>50% req served within (ms)</th>
      <th>90% req served within (ms)</th>
      <th>99% req served within (ms)</th>
      <th>100% req served within (ms)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Nginx 5.5 (OPcache) - 1 user</td>
      <td>2.12</td>
      <td>472.811</td>
      <td>472</td>
      <td>477</td>
      <td>491</td>
      <td>493</td>
    </tr>
    <tr>
      <td>HHVM - 1 user</td>
      <td>47.30</td>
      <td>21.140</td>
      <td>20</td>
      <td>21</td>
      <td>41</td>
      <td>66</td>
    </tr>
    <tr>
      <td>Nginx 5.5 (OPcache) - 10 user</td>
      <td>7.39</td>
      <td>1352.937</td>
      <td>1277</td>
      <td>1598</td>
      <td>1755</td>
      <td>1755</td>
    </tr>
    <tr>
      <td>HHVM - 10 user</td>
      <td>182.67</td>
      <td>54.743</td>
      <td>53</td>
      <td>81</td>
      <td>109</td>
      <td>134</td>
    </tr>
  </tbody>
</table>

So HHVM performs way better even compared to PHP 5.5 + OPcache when you've to do some hard work (who said Doctrine hydration?). So basically as I said before, you should test your application with HHVM (if it's compatbile) to know if it's worth the switch.

I have to remind you that these are just simple, stupid, tests, I'll try to keep the post updated when real-life examples are done.