# Turnbase

Turnbase is an [IcedCoffeeScript] framework for implementing
multiplayer online card games, board games, and other similar
turn-based games. The core of the project consists of three
components:

[IcedCoffeeScript]:http://maxtaco.github.io/coffee-script/

- A game specification DSL. The code for this resides primarily in the
  `game_engine` directory.
- A client-side interface for sending player actions and receiving
  game state updates. This lives in `game_engine/client/setup.iced`.
- A client-side canvas widget library to make building UIs easier. This
  resides in the `canvas` directory.

There is also a fair amount of server code thrown together to make
everything run.

## How to run

Note: This project is a work-in-progress, so setup is a little rough
around the edges. These instructions work for Ubuntu Linux. They
should mostly work for other operating systems but may require
manually performing steps in `scripts/setup_dev`.

Navigate to the project root directory. Then, run the following commands:
```
./dev.sh # sets up some environment variables
npm install
setup_dev # misc setup, including installing mysql and creating database
games_start # starts the server
```
You should now be able to visit the main page by going to
`localhost:8888` in a browser.

## Examples

Code for specific games reside in the `games` directory. See files in
`games/tictactoe` for a basic example. For a much more involved
example with detailed comments, see `games/battleship`.

To create a new game, simply create a new subdirectory of `games` with
an appropriate `config.iced` file; this will be automatically detected
after restarting the server. Besides `tictactoe` and `battleship`,
other games in the `games` directory are experimental; you are
encouraged to try them out, but they may occasionally be broken.

## Testing

There are a few tools in place to help with testing and debugging
games. Suppose you are working on `tictactoe`, and you are running
the server locally on port `8888`. You can test by going to
`localhost:8888/testing/tictactoe`, which will open two iframes which
you can use to play against yourself (note: you need to be logged
in). You can also save game states there to test from an intermediate
state.

Another tool that may be of use is the canvas debugger. It helps you
visualize the hierarchy of canvas UI elements. It can be accessed by
calling the function `DEBUG.debug_canvas()` in the JS console.


## Direction of the project

This is a somewhat cleaned-up version of a personal hobby project that
I started working on in 2013. I only have time to work on it
occasionally, so contributors/forks are welcome. Here are a few
medium-term improvements I have in mind:

- Implement a timer mechanism for games to facilitate e.g. time limits
  on turns.
- Provide a nice framework for animations in the client.
- Refactor `game_engine` and `canvas` into standalone modules.
- Make everything work with plain CoffeeScript by using `yield`
  statements.

And some long-term improvements:

- Reimplement `game_engine` as a proper DSL (i.e. with its own
  compiler and runtime) so that a lot of things can be checked at
  compile time.
- Reimplement `canvas` in WebGL for nicer-looking graphics.
