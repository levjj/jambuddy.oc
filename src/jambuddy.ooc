include jack/jack, jack/midiport

jack_options_t: extern cover

JackNullOption: extern jack_options_t

jack_client_t: extern cover

jack_client_open: extern func (client_name: CString,option: jack_options_t,status: Pointer) -> Pointer


main: func {
    "Initliazing Jack" println()
    client := jack_client_open("jambuddy", JackNullOption, null)
    match client {
        case null => fprintf (stderr, "Could not create JACK client.\n")
        case => fprintf (stderr, "Succesfully created JACK client.\n")
    }
}
