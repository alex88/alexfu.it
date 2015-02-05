---
date: 2012-10-01 23:09:58
title: Symfony 2.1, PHPUnit and Doctrine fixtures using SQLite
categories:
- Symfony
tags:
- symfony
- phpunit
- doctrine
- sqlite
---

Everyone should make tests for their applications, testing is the best way to develop new feature without breaking older ones.

For this purpose we're going to use [Doctrine Fixtures](https://github.com/doctrine/data-fixtures){:target='_blank'}'s [bundle](https://github.com/doctrine/DoctrineFixturesBundle){:target='_blank'} and [Liip function test bundle](http://packagist.org/packages/liip/functional-test-bundle){:target='_blank'} which loads fixtures on runtime during tests. These two bundles plus a SQLite db makes tests easy because you don't need a running MySQL server instance.

READMORE

### Setup

Installing the two bundles is easy as of Symfony 2.1 uses composer for managing packages. So add these lines to your composer.json require node:

``` json
{
    "doctrine/doctrine-fixtures-bundle": "dev-master",
    "liip/functional-test-bundle": "dev-master"
}
```

and into your app/AppKernel.php page add these two lines:

``` php
    new Liip\FunctionalTestBundle\LiipFunctionalTestBundle(),
    new Doctrine\Bundle\FixturesBundle\DoctrineFixturesBundle();
```


> It would be nice to load these modules only in test and/or dev environments, just compare them with $this->getEnvironment()

Last thing is to configure our test environement to use the bundles and the test SQLite db. So edit app/config/config_test.yml and add:

``` yaml
doctrine:
    dbal:
        default_connection: default
        connections:
            default:
                driver:     pdo_sqlite
                path:       %kernel.cache_dir%/test.db
                charset:    UTF8

liip_functional_test:
    cache_sqlite_db: true
```



### Usage


First step for using fixtures is to create a sample data which will be used in tests. Suppose we want to load some users and we've created our user bundle called Acme/UserBundle, let's create a file _src/Acme/UserBundle/DataFixtures/ORM/LoadUserData.php_ with this content:

``` php
<?php

namespace Acme\UserBundle\DataFixtures\ORM;

use Doctrine\Common\DataFixtures\FixtureInterface;
use Doctrine\Common\Persistence\ObjectManager;
use Doctrine\Common\DataFixtures\AbstractFixture;
use Acme\UserBundle\Entity\User;
use Symfony\Component\DependencyInjection\ContainerAwareInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;

class LoadUserData implements FixtureInterface, ContainerAwareInterface
{

    /**
     * @var ContainerInterface
     */
    private $container;

    /**
     * {@inheritDoc}
     */
    public function setContainer(ContainerInterface $container = null)
    {
        $this->container = $container;
    }

    /**
     * {@inheritDoc}
     */
    public function load(ObjectManager $manager)
    {
        $userManager = $this->container->get('fos_user.user_manager');
        $user = $userManager->createUser();
        $user->setUsername('admin');
        $user->setEmail('admin@test.com');
        $user->setPlainPassword('test');
        $userManager->updateUser($user, false);
        $manager->persist($user);
        $manager->flush();
    }
}
```


In this example I'm using the [FOS UserBundle](https://github.com/FriendsOfSymfony/FOSUserBundle){:target='_blank'} for user management, but you can use the Entity as usual. Refer to [this](http://symfony.com/doc/current/bundles/DoctrineFixturesBundle/index.html){:target='_blank'} page for further informations.

Now that we've created some data, let's use this data in the tests, suppose that we've an ApiBundle with some tests inside, let's use the fixtures. To do so just be sure to implement Liip\FunctionalTestBundle\Test\WebTestCase and not the Symfony default, then in the test run this:

``` php
$classes = array(
        'Acme\UserBundle\DataFixtures\ORM\LoadUserData'
);
$this->loadFixtures($classes);
```

This will load the UserBundle fixture for this test.

Repeat these steps for creating more fixtures and load different combinations of them.

Good luck ;)
