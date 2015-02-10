---
date: 2012-09-10 19:11:17
title: Jenkins and Symfony 2.1
priority: 0.9
changefreq: daily
categories:
- Symfony
tags:
- jenkins
- symfony
- ci
- continuous integration
---

At work we've start ed Test-driven development and I was going to use [Jenkins](http://jenkins-ci.org/){:target='_blank'} for continuous integration and testing.

To add a job for correctly running tests within Jenkins i had to fork the [xurumelous' jenkins settings](https://github.com/xurumelous/symfony2-jenkins-template){:target='_blank'} repository and change some code to get it working with the new Symfony 2.1 which uses composer to get the libraries.

READMORE

The changes will just download composer.phar and run an install of the vendors to get all the libraries defined in your composer.json.

You can download the code at my repository [here](https://github.com/alex88/symfony2.1-jenkins-template){:target='_blank'}.
