export async function executeFetch() {
    const response = await fetch('/Endaxis/gamedata.json')

    if (!response.ok) {
        throw new Error(`Local load failed: ${response.statusText}`)
    }

    return await response.json()
}