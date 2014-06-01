import math
import text/StringTokenizer
import structs/HashBag

include jack/jack, jack/midiport

jack_midi_event_reserve: extern func (buffer: Pointer, i: Int,size: SizeT) -> UChar*

Event: cover {
    noteOn: Bool = true
    note: UInt
    velocity: UInt
    frame: UInt
    init: func@ (=frame,=note,=velocity)
    fromObject: func@ (obj:HashBag) {
        frame = obj get("frame", UInt)
        note = obj get("note", UInt)
        velocity = obj get("velocity", UInt)
    }
    toString: func -> String {
        "{frame:#{this frame},note:#{this note},velocity:#{this velocity}},"
    }
}

powers := [1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0, 64.0]
eta:Double = 0.05
norm:Double = 60 * 4 * 48000 // seconds per minute * beats per bar * sample rate

min: func (a,b: Double) -> Double {
    if (a < b) return a;
    return b;
}

max: func (a,b: Double) -> Double {
    if (a > b) return a;
    return b;
}

Player: class {
    first: Bool
    spn: Double
    phase: Long
    last: UInt
    playing: Bool
    dynamic: Double
    lastNote: UInt
    subphase: UInt
    drums:Instrument*

    init: func() {
        first = true
        spn = 48000.0
        phase = 1
        dynamic = 0.0
        lastNote = 0
        subphase = 0
        drums = Drums new()
    }

    updateTempo: func (delta: UInt) {
        if (delta < 48000 / 200) return;
        first:Bool = true
        minLoss:Double = 0.0
        index:UInt = -1
        for (i in 0..12) {
            // printf("Power %d is %.4f\n", i, powers[i])
            pred := spn / powers[i]
            loss := (pred - delta as Double) * powers[i]
            // printf("1/%.4f predicts %.4f frames and gets loss %.4f\n", powers[i], pred, loss)
            if (first || abs(loss) < abs(minLoss)) {
                minLoss = loss
                index = i
            }
            first = false
        }
        // printf("The smallest loss is %.4f -> update spn with %.4f\n", minLoss, eta * minLoss)
        // printf ("tempo = %.4f", 1.0/ (spn / 48000) * 4 * 60)
        // phase = phase * (spn - eta * minLoss) / spn
        // spn = max(8400,min(96000, spn - eta * minLoss))
        spn = spn - eta * minLoss
        if (spn < 24400) spn *= 2
        if (spn > 60400) spn /= 2
        spn = (spn / 480) round() * 480
        // spn = delta
        printf (" -> %.4f\n", 1.0/ (spn / 48000) * 4 * 60)
    }

    noteOn: func(time: UInt, pitch: UInt, velocity: UInt) {
        printf ("delay = %d pitch = %d velocity = %d\n", time - last, pitch, velocity)
        if (last > 0) update(time - last)
        last = time
    }
}
