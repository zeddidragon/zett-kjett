# ZettKjett

When in a functional state, this program will allow you to use your terminal
to chat in many different protocols.

However, the project is still in early development and cannot do any of that.

## Discord

Before you can use discord, you must insert a token in config.toml with the
format
```toml
[discord]
token = "<your token>"
```

To get a token, log in to discord in the browser, open up the web inspector
(Ctrl/Cmd  + Shift + I), go to the "Application" tab and copy the value under
localStorage named "token".

https://www.reddit.com/r/discordapp/comments/5ncwpv/localstorage_missing/

The reason for using that token instead of username and password is that it is
less frowned upon by the developers. Not endorsed, per se, just less frowned upon.

https://github.com/hammerandchisel/discord-api-docs/issues/69#issuecomment-223886862
