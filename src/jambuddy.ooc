import os/Time
import player
include stdio, jack/jack, jack/midiport

jack_options_t: extern cover
jack_client_t: extern cover
jack_nframes_t: extern cover

JackNullOption: extern jack_options_t

jack_client_open: extern func (client_name: CString,
                               option: jack_options_t,
                               status: Pointer) -> Pointer

jack_set_process_callback: extern func (client: Pointer,
                                        callback: Func(jack_nframes_t, Pointer) -> Int,
                                        arg: Int) -> Pointer

jack_port_register: extern func (client: Pointer,
                                 portName: CString,
                                 portType: CString,
                                 flags: ULong,
                                 bufferSize: ULong) -> Pointer

jack_activate: extern func (client: Pointer) -> Int
jack_port_get_buffer: extern func (port: Pointer, frames: jack_nframes_t) -> Pointer
jack_midi_get_event_count: extern func (buffer: Pointer) -> Int

JackEvent: cover from jack_midi_event_t {
    time: jack_nframes_t
    buffer: CString
}

jack_midi_event_get: extern func (evt: JackEvent*, buffer: Pointer, i: Int) -> Int

port:Pointer = null
tframes:UInt = 0

player:Player

process: func (frames: jack_nframes_t, arg:Pointer) -> Int {
    buffer:Pointer = jack_port_get_buffer(port, frames)
    n:Int = jack_midi_get_event_count (buffer)

    for (i in 0..n) {
        evt:JackEvent
        if (0 == jack_midi_event_get(evt&, buffer, i)) {
            type:Char = (evt buffer)[0] & 0xf0
            if (type != 0x90) continue
            time:UInt = evt time as UInt + tframes as UInt
            player.noteOn(time, (evt buffer)[1] as UInt, (evt buffer)[2] as UInt)
        }
    }
    tframes += frames as UInt

    return 0;
}

main: func {
    "Initliazing Jack" println()

    client:Pointer = jack_client_open("jambuddy", JackNullOption, null)
    if (client == null) {
        "Could not create JACK client." println()
        exit (EXIT_FAILURE)
    }

    jack_set_process_callback (client, process, 0)

    port = jack_port_register (client, "input", "8 bit raw midi", 1, 0)

    if (port == null) {
        "Could not register port." println()
        exit (EXIT_FAILURE)
    }

    player = Player new()

    r:Int = jack_activate (client)
    if (r != 0) {
        "Could not activate client." println()
        exit (EXIT_FAILURE)
    }
    while (true) {
        match (fgetc(stdin)) {
            case 10 => exit (0)
            case 13 => exit (0)
            case => Time sleepSec(1)
        }
    }
}
