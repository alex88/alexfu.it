#= require jquery
#= require fancybox/source/jquery.fancybox
#= require bootstrap

$ ->
  $('a[rel="lightbox"]').fancybox()

((i, s, o, g, r, a, m) ->
  i['GoogleAnalyticsObject'] = r
  i[r] = i[r] or ->
    (i[r].q = i[r].q or []).push arguments
    return

  i[r].l = 1 * new Date
  a = s.createElement(o)
  m = s.getElementsByTagName(o)[0]
  a.async = 1
  a.src = g
  m.parentNode.insertBefore a, m
  return
) window, document, 'script', '//www.google-analytics.com/analytics.js', 'ga'
ga 'create', 'UA-41042463-2', 'auto'
ga 'require', 'linkid', 'linkid.js'
ga 'send', 'pageview'