---
date: 2018-12-07 19:14:00
title: Use container labels in docker logging tags
priority: 0.9
changefreq: daily
categories:
- Docker
- Tips
tags:
- docker
- logs
- service
- stack
- aws cloudwatch
---

Today I've created a docker swarm cluster and I wanted to send all docker logs to the AWS Cloudwatch Logs service.
Since I'm going to deploy the docker containers as stacks with services, I wanted to be able to have a cloudwatch stream
namd like this: `stack/service/container/id`.

Unfortunately looking at the docker [documentation](https://docs.docker.com/v17.09/engine/admin/logging/log_tags/){:target='_blank'} the tags available aren't enough to have the service and stack name.

READMORE

### Solution

After trying different random values and getting a lot of:

```
starting container failed: failed to initialize logging driver: template: log-tag:1:2: executing "log-tag" at <.ServiceName>: can't evaluate field ServiceName in type *logger.Info
```

I've found the source file that contains the context that's available in the go template docker is parsing,
[here](https://github.com/moby/moby/blob/8e610b2b55bfd1bfa9436ab110d311f5e8a74dcb/daemon/logger/loginfo.go#L12-L25){:target='_blank'}.

So after looking at the golang template [docs](https://golang.org/pkg/text/template/){:target='_blank'} I've been finally able to get what I wanted.

So to have a stream like this:

```
stack name/service name/container name/truncated container id
```

you need a log tag option like this:

```
{{if (index .ContainerLabels "com.docker.stack.namespace")}}{{index .ContainerLabels "com.docker.stack.namespace"}}/{{end}}{{if (index .ContainerLabels "com.docker.swarm.service.name")}}{{index .ContainerLabels "com.docker.swarm.service.name"}}/{{end}}{{.Name}}/{{.ID}}
```

You can set this globally setting your `/etc/docker/daemon.json/ like this:

```
{
  "log-driver": "awslogs",
  "log-opts": {
    "awslogs-region": "us-west-1",
    "awslogs-group": "your-group-name-here",
    "tag": "{{if (index .ContainerLabels \"com.docker.stack.namespace\")}}{{index .ContainerLabels \"com.docker.stack.namespace\"}}/{{end}}{{if (index .ContainerLabels \"com.docker.swarm.service.name\")}}{{index .ContainerLabels \"com.docker.swarm.service.name\"}}/{{end}}{{.Name}}/{{.ID}}"
  }
}
```
