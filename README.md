# Wordpress Docker image for Plugin, Theme and MultiSite Development

This image is intended for *local development only*. It runs Nginx and PHP-FPM as the *root user* so that Docker volumes mounted at /var/www/html can be written by the server processes.

This is totally awesome for local theme and plugin development, and the worst of all possible worlds if it happens to end up on a real server, so don't. Just don't. :simple_smile:

## Usage

For more detail, see this [initial blog post](http://goldsounds.com/archives/2015/04/06/quick-and-easy-wordpress-development-using-docker/) and the follow up where I [enable multi-site](http://goldsounds.com/archives/2015/04/16/docker-for-wordpress-multisite-development/).

I use this image with [Docker Compose](https://docs.docker.com/compose/), thusly:

0. Install Docker and Docker Compose. Instructions will vary depending on your system.

1. Save the following in a repo somewhere as docker-compose.yml:

```yaml
wordpress:
  image: gravityrail/wordpress
  volumes:
    - src:/var/www/html
  links:
    - db:mysql
  ports:
    - 8080:80

db:
  image: mariadb
  environment:
    MYSQL_ROOT_PASSWORD: example
```

2. Create a directory call "src" in the same directory as docker-compose.yml

3. Run `docker-compose up`. This will boot the WordPress and MariaDB docker images, install WordPress to your "src" directory, and run the server process.

4. run `open "http://$(boot2docker ip):8080"`, and install (for Linux, YMMV)

You can now install themes and plugins and mess with WordPress as much as you like!

## Scripting the container with wp-cli

You can run the "[wp](http://wp-cli.org/)" cli command as long as you include the "--allow-root" option, for example:

```bash
docker-compose run wordpress wp --allow-root plugin install hello-dolly
```

Nice, but noisy. On my own system (OS X, but this would work in Linux too), I created a wrapper for this using `alias` in my `~/.profile`:

```bash
alias docker-wp='docker-compose run wordpress wp --allow-root'
```

Which turns the above command into:

```bash
docker-wp plugin install hello-dolly
```

Another example - let's create a new plugin!

```bash
docker-wp scaffold plugin my_super_plugin --plugin_name="My Super Plugin" 
```

AWESOMESAUCE.

## Enable MultiSite

The magical, [wp-cli](http://wp-cli.org/commands/core/multisite-convert/) way:

```bash
docker-wp core multisite-convert --title="My Blog Network"
```

One caveat of the configuration is that I use "folder" rather than "subdomain" MultiSite, for ease of use. I leave the necessary DNS shenanigans for local subdomain development as an exercise for the reader :simple_smile:

## Credits

All credit must go to https://github.com/docker-library/wordpress, from which this code was shamelessly and inexpertly copied.