# track-explorer

track-explorer is a tool that uses data available on [1001 Tracklists](http://www.1001tracklists.com/) to recommend similar tracks.

It finds all tracklists that contain a given track, and then scores each track in those tracklists according to their distance in the tracklist from the input track.

### Usage

First, find the track you want to search for on 1001 Tracklists and copy the slug from the URL.

For instance, given the URL:

```
http://www.1001tracklists.com/track/81480_octane-dlr-break-murmur/index.html
```

The slug would be `81480_octane-dlr-break-murmur`.

Then pass that slug as a command line argument to `track-explorer.rb`:

```
λ ./track-explorer.rb 81480_octane-dlr-break-murmur
     Inf    Murmur - Octane & DLR & Break
    7.21    Drift - Metrik
    5.32    Dustup - Noisia & The Upbeats
    4.13    Automatic - Wilkinson
    3.13    Elevate This Sound - Calyx & TeeBee
...
```
