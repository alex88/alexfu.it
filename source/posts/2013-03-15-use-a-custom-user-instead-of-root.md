---
date: 2013-03-15 15:16:50
title: 'Capistrano: use a custom user instead of root with sudo'
priority: 0.9
changefreq: daily
categories:
- Symfony
- Tools
---

It's a while that we use Capifony (capistrano addon for symfony 2 deployment) for our work projects.

This week we've switched to new servers so I decided to not use a custom user for nginx/php-fpm and stick to the default www-data. However, the deploy process is run by the ssh user which is not www-data.

Capistrano has an option called use_sudo that makes it use sudo every time it needs. I didn't liked this approach since I wanted to have all files owned by www-data and not root.
After some researches I've seen that there isn't a "default" way to select which user sudo to.

I've just found a tricky workaround that makes capistrano sudo to another user, change the default shell :)

To do this just add this line to your **deploy.rb**:

``` ruby
set :default_shell,         "sudo -u www-data /bin/sh"
```

this basically wraps every command using sudo command setting the desired user, in this way you'll have all the code and files owned by www-data.

**Note:** in case you get a warning like:

``` plain
No entry for terminal type "unknown";
using dumb terminal settings.
```

Just add at the beginning the terminal type, like:

``` sh
set :default_shell,         "TERM=dumb sudo -u www-data /bin/sh"
```

Have fun ;)
