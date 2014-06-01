import os/Time
import io/File
import io/FileReader
import text/json
import structs/Bag
import structs/HashBag
import structs/ArrayList

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
jack_midi_clear_buffer: extern func (buffer: Pointer)
jack_midi_get_event_count: extern func (buffer: Pointer) -> Int

JackEvent: cover from jack_midi_event_t {
    time: jack_nframes_t
    buffer: CString
}

jack_midi_event_get: extern func (evt: JackEvent*, buffer: Pointer, i: Int) -> Int

port:Pointer = null
out:Pointer = null
tframes:UInt = 0

player:Player

process: func (frames: jack_nframes_t, arg:Pointer) -> Int {
    // process input
    buffer:Pointer = jack_port_get_buffer(port, frames)
    n:Int = jack_midi_get_event_count (buffer)
    for (i in 0..n) {
        evt:JackEvent
        if (0 == jack_midi_event_get(evt&, buffer, i)) {
            type:Char = (evt buffer)[0] & 0xf0
            if (type != 0x90) continue
            time:UInt = evt time as UInt + tframes
            e:Event
            e init(time, (evt buffer)[1] as UInt, (evt buffer)[2] as UInt)
            player.noteOn(e, tframes)
        }
    }

    // generate output
    buffer = jack_port_get_buffer(out, frames)
	jack_midi_clear_buffer(buffer)
    player.playDrums(buffer, frames as UInt)

    // post processing
    tframes += frames as UInt
    return 0;
}

parse: func (content: HashBag) -> ArrayList<Event> {
    result := ArrayList<Event> new()
    notes:Bag = content get("notes", Bag)
    for (i in 0..notes size) {
        noteObj:HashBag = notes get(i, HashBag)
        e:Event
        e fromObject(noteObj)
        result add(e)
    }
    return result
}

testWithNotes: func (notes: ArrayList<Event>) {

}

main: func (nargs: Int, args: CString*) {
    if (nargs > 1) {
        file:FileReader = FileReader new(args[1] toString())
        data:ArrayList<Event> = parse(JSON parse(file))
        file close()
        testWithNotes(data)
        exit (EXIT_SUCCESS)
    }
    client:Pointer = jack_client_open("jambuddy", JackNullOption, null)
    if (client == null) {
        "Could not create JACK client." println()
        exit (EXIT_FAILURE)
    }

    jack_set_process_callback (client, process, 0)

    port = jack_port_register (client, "input", "8 bit raw midi", 1, 0)
    out = jack_port_register (client, "output", "8 bit raw midi", 2, 0)

    if (port == null) {
        "Could not register port." println()
        exit (EXIT_FAILURE)
    }

    player = Player new()
    printf("Frame,Tempo,Dynamic,Loss,C,C#,D,D#,E,F,F#,G,G#,A,A#,B,Cs,C#s,Ds,D#s,Es,Fs,F#s,Gs,G#s,As,A#s,Bs\n")

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
