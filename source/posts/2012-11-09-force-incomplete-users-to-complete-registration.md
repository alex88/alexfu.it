---
date: 2012-11-09 19:43:00
title: 'Symfony 2: Force incomplete users to complete registration'
priority: 0.9
changefreq: daily
categories:
- Symfony
---

Last week I've completed social login into our work project using [HWIOAuthBundle](https://github.com/hwi/HWIOAuthBundle){:target='_blank'} and I figured out that the twitter oauth wasn't providing the user email address.

Since we use the email address a lot, also because without you can't recover password or being contacted by our admin team, we need that every user has their email set.

My first idea was to check for user email with a request listener, but that would be too expensive. I've though also of editing the auth/user provider to don't let the user login in case of missing email, but in that case i should have the user to complete the registration without being logged in which maybe can create some security issues.

The solution I've found is to edit the user roles in case of the user is incomplete and replace them with `ROLE_INCOMPLETE_USER`.
So all the requests that required the `ROLE_USER` role will be denied and redirected to the complete registration form.


### The user entity

In our user entity we edit these methods:

``` php
<?php

namespace Acme\UserBundle\Entity;

use Symfony\Component\Security\Core\User\AdvancedUserInterface;
use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Bridge\Doctrine\Validator\Constraints\UniqueEntity;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\ORM\Mapping as ORM;

/**
 * Acme\UserBundle\Entity\User
 *
 * @ORMTable()
 * @ORMEntity(repositoryClass="Acme\UserBundle\Entity\UserRepository")
 * @UniqueEntity("email")
 */
class User implements AdvancedUserInterface, Serializable
{
    ....

    /**
     * Return the user roles
     */
    public function getRoles()
    {
        if(!$this->isRegistrationCompleted()) {
            return array('ROLE_INCOMPLETE_USER');
        }
        return $this->groups->toArray();
    }

    /**
     * Check if the user has all the mandatory fields
     */
    public function isRegistrationCompleted()
    {
        if(empty($this->email))
            return false;
        return true;
    }

    ....
}
```


In this way we can add other mandatory fields just adding them in the isRegistrationCompleted() function.
Basically in this way an incomplete user always has the `ROLE_INCOMPLETE_USER` role and not the `ROLE_USER`.


### The access denied listener


Now when the user tries to access a page that requires another role (`ROLE_USER` for example) gets an access denied exception, so to redirect the user to the complete registration form we have to handle this access denied exception and in case the user has the `ROLE_INCOMPLETE_USER` redirect him to the complete registration form.

To do so we need to create an handler that gets notified of an access denied exception. The first step is to set the handler in our firewall, in my case the firewall is called main so we add this setting in the security.yml file:

``` yaml
security:
    firewalls:
        main:
            access_denied_handler:      acme.access_denied.handler
```

Then declare our service:

``` yaml
services:
    acme.access_denied.handler:
        class:           AcmeUserBundleListenerUserIncompleteListener
        arguments:
            security:    @security.context
            router:      @router
```

And here's the code of the UserIncompleteListener

``` php
<?php

namespace Acme\UserBundle\Listener;

use Symfony\Component\HttpKernel\Event\GetResponseEvent;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Security\Core\Exception\AccessDeniedException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\Security\Http\Authorization\AccessDeniedHandlerInterface;

class UserIncompleteListener implements AccessDeniedHandlerInterface
{
    protected $security;
    protected $router;

    public function __construct($security, $router)
    {
        $this->security = $security;
        $this->router = $router;
    }

    public function handle(Request $request, AccessDeniedException $accessDeniedException)
    {
        if(!is_null($this->security->getToken()->getUser()->getRoles()) &&  $this->security->getToken()->getUser()->getRoles() == array('ROLE_INCOMPLETE_USER')) {
            return new RedirectResponse($this->router->generate('register_complete'));
        }
    }
}
```


The handle function checks that the user is logged and in the case the user has only the `ROLE_INCOMPLETE_USER` role it redirects him to the complete registration form role.

The form is up to you, it's pretty simple, you have just to create a form to edit the required fields of the user.


> TIP: To additional security, restrict with access control the complete registration form only to users with the `ROLE_INCOMPLETE_USER` role


That's it! If you have some questions just drop a comment ;)
