import math

powers := [1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0, 64.0]
eta:Double = 0.3
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
    last: UInt
    spn: Double

    init: func {
        last = 0
        spn = 48000.0
    }

    update: func (delta: UInt) {
        minLoss:Double = 80000.0
        for (i in 0..1) {
            printf("Power %d is %.4f\n", i, powers[i])
            pred := spn / powers[i]
            loss := (pred - delta as Double) * powers[i]
            printf("1/%.4f predicts %.4f frames and gets loss %.4f\n", powers[i], pred, loss)
            if (abs(loss) < abs(minLoss)) minLoss = loss
        }
        printf("The smallest loss is %.4f -> update spn with %.4f\n", minLoss, eta * minLoss)
        printf ("tempo = %.4f", 1.0/ (spn / 48000) * 4 * 60)
        spn = spn - eta * minLoss
        // spn = delta
        printf (" -> %.4f\n", 1.0/ (spn / 48000) * 4 * 60)
    }

    noteOn: func(time: UInt, pitch: UInt, velocity: UInt) {
        printf ("delay = %d pitch = %d velocity = %d\n", time - last, pitch, velocity)
        if (last > 0) update(time - last)
        last = time
    }
}
