import math
import text/StringTokenizer
import structs/HashBag
import structs/ArrayList

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

POWERS:Double[12] = [1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0, 64.0]
ETA:Double = 0.05
NORM:Double = 60 * 4 * 48000 // seconds per minute * beats per bar * sample rate

DISS_I:Double[12] = [0.0,1.0,0.75333247,0.59523746,0.65496354,0.42311628,0.6846481,
                     0.42311628,0.65496354,0.59523746,0.75333247,1.0]
ETA2:Double = 1.2
ALPHA:Double = 0.1


umin: func (a,b: UInt) -> UInt {
    if (a < b) return a;
    return b;
}

umax: func (a,b: UInt) -> UInt {
    if (a > b) return a;
    return b;
}

min: func (a,b: Double) -> Double {
    if (a < b) return a;
    return b;
}

max: func (a,b: Double) -> Double {
    if (a > b) return a;
    return b;
}

Instrument: class {
    init: func {}
    play: func(subphase:UInt) -> Event {
        return Event new(0, 0, 0)
    }
}

Drums: class extends Instrument {
    init: super func
    play: func(subphase:UInt) -> Event {
        return match (subphase) {
            case 0 => Event new(0,36,100)
            case 1 => Event new(0,42,50)
            case 2 => Event new(0,38,30)
            case 3 => Event new(0,42,50)
            case 4 => Event new(0,36,80)
            case 5 => Event new(0,42,50)
            case 6 => Event new(0,38,30)
            case 7 => Event new(0,42,50)
        }
    }
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
    v_w: ArrayList<Double>
    v_s: ArrayList<Double>
    loss: Double
    drums:Instrument*


    init: func() {
        first = true
        spn = 48000.0
        phase = 1
        dynamic = 0.0
        lastNote = 0
        subphase = 0
        loss = 0
        v_w = ArrayList<Double> new()
        v_s = ArrayList<Double> new()
        for (i in 0..12) {
            v_w.add(1.0 / 12.0)
            v_s.add(1.0 / 12.0)
        }
        drums = Drums new()
    }

    updateTempo: func (delta: UInt) {
        if (delta < 48000 / 200) return;
        first:Bool = true
        minLoss:Double = 0.0
        index:UInt = -1
        for (i in 0..12) {
            // printf("Power %d is %.4f\n", i, powers[i])
            pred := spn / POWERS[i]
            loss := (pred - delta as Double) * POWERS[i]
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
        spn = spn - ETA * minLoss
        if (spn < 24400) spn *= 2
        if (spn > 60400) spn /= 2
        spn = (spn / 480) round() * 480
        // spn = delta
        // printf (" -> %.4f\n", 1.0/ (spn / 48000) * 4 * 60)
        dynamic = max(0.0, min(1.0, 0.125 + 0.75*(dynamic + 0.05 * ((index as Double) - 3))))
    }

    updatePhase: func(delta: UInt) {
        diff:Double = abs(-phase + delta) as Double
        if (diff > spn / 2) diff -= spn / 2
        alpha:Double = (-(diff/1000)*(diff/1000)) exp()
        // "delta = #{delta} phase = #{phase}, diff=#{diff}, alpha=#{alpha}" println()
        phase = ((delta as Double) * alpha + (phase as Double) * (1 - alpha)) roundLong()
        // "->phase = #{phase}" println()
    }

    updateDynamic: func(velocity: UInt) {
        dynamic = max(0.0, min(1.0, 0.125 + 0.75*(dynamic + 0.0025 * ((velocity as Double) - 64.0))))
        // "dynamics = #{dynamic}" println()
    }

    diss: func(pred:UInt, data:UInt) -> Double {
        interval:UInt = umax(pred,data) - umin(pred,data)
        interval = interval % 12
        return DISS_I[interval]
    }

    updateHarmony: func(pitch: UInt) {
        ltm,v:Double[12]
        for (i in 0..12) {
            ltm[i] = diss(i,pitch)
            loss += v_w[i] * ltm[i]
        }
        sum:Double = 0.0
        for (i in 0..12) {
            v[i] = v_w[i] * ((-1.0 * ETA2 * ltm[i]) exp())
            sum += v[i]
        }
        for (i in 0..12) {
            v_w[i] = ((1.0 - ALPHA) * (v[i] / sum)) + (ALPHA * v_s[i])
            v_s[i] = ((1.0 - ALPHA) * v_s[i]) + (ALPHA * (v[i] / sum))
        }
    }

    noteOn: func(evt: Event, tframes: UInt) {
        // evt toString() println()
        if (first) {
            first = false
            last = evt frame
        } else {
            updateTempo(evt frame - last)
            // updatePhase(evt frame - tframes)
            updateDynamic(evt velocity)
            last = evt frame
        }
        updateHarmony(evt note)
        log(evt)
    }

    log: func(evt: Event) {
        printf("%d,%.4f,%.4f,%.4f,",
               evt frame,
               1.0/ (spn / 48000) * 4 * 60,
               dynamic,
               loss)
        printf("%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,",
               v_w[0],v_w[1],v_w[2],v_w[3],v_w[4],v_w[5],v_w[6],v_w[7],v_w[8],v_w[9],v_w[10],v_w[11])
        printf("%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n",
               v_s[0],v_s[1],v_s[2],v_s[3],v_s[4],v_s[5],v_s[6],v_s[7],v_s[8],v_s[9],v_s[10],v_s[11])
        fflush(stdout)
    }

    play: func(buffer:Pointer, frames: UInt, instrument: Instrument*) {
        for (i in 0..frames) {
            // "phase = #{phase}" println()
            phase -= 1
            // "-> #{phase}" println()
            if (phase == 0) {
                playNoteOff(i, buffer)
                evt:Event = instrument play(subphase)
                playNoteOn(i+1, buffer, evt note,evt velocity)
                phase = spn roundLong() / 4
                subphase += 1
                if (subphase == 8) subphase = 0
            }
        }
    }

    playDrums: func(buffer:Pointer, frames: UInt) {
        play(buffer, frames, drums)
    }

    playNoteOn: func(i:UInt, buffer:Pointer, pitch:UInt, velocity:UInt) {
        vel:Double = (dynamic + ((velocity as Double)/100) - 1.0) * 127
        // "NoteOn (i=#{i},vel=#{vel},pitch=#{pitch})" println()
        if (vel <= 0) return
        evt:UChar* = jack_midi_event_reserve(buffer, i, 3)
        evt[2] = vel as UChar // velocity
        evt[1] = pitch as UChar // pitch
        evt[0] = 0x90 as UChar // note on
        lastNote = pitch
    }

    playNoteOff: func(i:UInt, buffer:Pointer) {
        if (lastNote == 0) return
        evt:UChar* = jack_midi_event_reserve(buffer, i, 3)
        // "NoteOff (i=#{i})" println()
        evt[2] = 64 as UChar // velocity
        evt[1] = lastNote as UChar // pitch
        evt[0] = 0x80 as UChar // note off
    }
}
