pragma Singleton
import QtQuick

QtObject {
    function costInCopper(text) {
        if (!text) return Number.POSITIVE_INFINITY
        const m = String(text).match(/^\s*([\d,]+)\s*([A-Z]{2})/)
        if (!m) return Number.POSITIVE_INFINITY
        const amount = parseInt(m[1].replace(/,/g, ""), 10)
        if (isNaN(amount)) return Number.POSITIVE_INFINITY
        const mult = { CP: 1, SP: 10, EP: 50, GP: 100, PP: 1000 }[m[2]]
        return mult === undefined ? Number.POSITIVE_INFINITY : amount * mult
    }

    function formatCopper(cp) {
        if (cp <= 0) return qsTr("—")
        const parts = []
        let rem = cp
        const pp = Math.floor(rem / 1000); rem -= pp * 1000
        const gp = Math.floor(rem / 100);  rem -= gp * 100
        const sp = Math.floor(rem / 10);   rem -= sp * 10
        if (pp) parts.push(pp + " PP")
        if (gp) parts.push(gp + " GP")
        if (sp) parts.push(sp + " SP")
        if (rem) parts.push(rem + " CP")
        return parts.join(", ")
    }
}
