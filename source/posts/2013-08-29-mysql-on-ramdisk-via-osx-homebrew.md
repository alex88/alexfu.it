---
date: 2013-08-29 11:36:00
title: Mysql on ramdisk via osx homebrew
priority: 0.9
changefreq: daily
categories:
- Tips
tags:
- mysql
- ramdisk
- osx
---

Having mysql running on a ramdisk can be a much faster way to unit test a database intensive application.

Supposing you've installed mysql or percosa server via homebrew (cause the paths it uses) you can directly run this script to create a virtual disk and run a mysql instance on it.
It will create a simple configuration file stored in `/usr/local/etc/my_ramdisk.cnf` which will be used by the additional mysql instance.

By default the server will run on port 3307 listening on 0.0.0.0.

Here is the attached script:

<script src="https://gist.github.com/alex88/6038973.js"></script>

Just run it via ./mysql\_ramdisk.rb and shutdown using ./mysql\_ramdisk shutdown ;)