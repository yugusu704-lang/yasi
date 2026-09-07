import asyncio
import json
import os
import subprocess
import edge_tts

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT_DIR, "assets")
DEMO_DIR = os.path.join(ASSETS_DIR, "demo")
SENTENCES_DIR = os.path.join(ASSETS_DIR, "audio", "sentences")
TEMP_DIR = os.path.join(ROOT_DIR, "scripts", "temp_audio")

VOICE_SURVEYOR = "en-GB-RyanNeural"  # Male British
VOICE_LUISA = "en-GB-SoniaNeural"    # Female British
VOICE_VOCAB = "en-GB-SoniaNeural"

VOCAB_SENTENCES = {
    "punctuality": "How would you rate the punctuality and frequency of the train service?",
    "commuting": "Is your journey for commuting or leisure purposes?",
    "overcrowded": "The carriages are often overcrowded, especially between 8 and 9 AM.",
    "consultant": "I work as an environmental consultant in the city center.",
    "accommodation": "The student union provides affordable student accommodation near campus.",
    "sustainable": "Investing in sustainable public transport reduces carbon emissions.",
    "carriages": "During rush hours, the railway carriages are packed with commuters.",
    "fares": "Bus and train fares have increased considerably over the past year."
}

def get_audio_duration_ms(file_path: str) -> int:
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        file_path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    seconds = float(result.stdout.strip())
    return int(round(seconds * 1000))

async def synthesize_text(text: str, voice: str, out_path: str):
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(out_path)

async def main():
    os.makedirs(TEMP_DIR, exist_ok=True)
    os.makedirs(SENTENCES_DIR, exist_ok=True)
    os.makedirs(DEMO_DIR, exist_ok=True)

    print("=== 1. Generating Vocabulary Example Sentences ===")
    for word, sentence in VOCAB_SENTENCES.items():
        out_file = os.path.join(SENTENCES_DIR, f"{word}.mp3")
        print(f"Generating vocab audio: {word} -> {out_file}")
        await synthesize_text(sentence, VOICE_VOCAB, out_file)
        dur = get_audio_duration_ms(out_file)
        print(f"  Done ({dur} ms, {os.path.getsize(out_file)} bytes)")

    print("\n=== 2. Generating Cambridge 18 Test 1 Section 1 Dialogue ===")
    json_path = os.path.join(DEMO_DIR, "cambridge_18_test1_s1.json")
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # 800ms silence between sentences
    silence_file = os.path.join(TEMP_DIR, "silence_800ms.mp3")
    silence_cmd = [
        "ffmpeg", "-y", "-f", "lavfi",
        "-i", "anullsrc=r=44100:cl=stereo",
        "-t", "0.8",
        "-q:a", "9",
        "-acodec", "libmp3lame",
        silence_file
    ]
    subprocess.run(silence_cmd, capture_output=True, check=True)
    silence_ms = get_audio_duration_ms(silence_file)

    current_ms = 0
    segment_files = []
    concat_list_path = os.path.join(TEMP_DIR, "concat_list.txt")

    with open(concat_list_path, "w", encoding="utf-8") as concat_f:
        for item in data["sentences"]:
            idx = item["index"]
            text = item["textEn"]
            # Even indices: Surveyor (Ryan), Odd indices: Luisa (Sonia)
            voice = VOICE_SURVEYOR if idx % 2 == 0 else VOICE_LUISA
            seg_file = os.path.join(TEMP_DIR, f"seg_{idx}.mp3")

            print(f"Synthesizing sentence {idx} ({voice}): {text[:30]}...")
            await synthesize_text(text, voice, seg_file)
            dur_ms = get_audio_duration_ms(seg_file)

            item["startMs"] = current_ms
            item["endMs"] = current_ms + dur_ms
            print(f"  Sentence {idx}: {item['startMs']}ms -> {item['endMs']}ms (dur: {dur_ms}ms)")

            concat_f.write(f"file '{os.path.abspath(seg_file).replace(chr(92), '/')}'\n")
            current_ms += dur_ms

            if idx < len(data["sentences"]) - 1:
                concat_f.write(f"file '{os.path.abspath(silence_file).replace(chr(92), '/')}'\n")
                current_ms += silence_ms

    final_mp3 = os.path.join(DEMO_DIR, "c18_t1_s1.mp3")
    print(f"\nConcatenating dialogue into {final_mp3}...")
    concat_cmd = [
        "ffmpeg", "-y", "-f", "concat", "-safe", "0",
        "-i", concat_list_path,
        "-c", "copy",
        final_mp3
    ]
    subprocess.run(concat_cmd, capture_output=True, check=True)

    total_dur_ms = get_audio_duration_ms(final_mp3)
    data["totalDurationMs"] = total_dur_ms
    data["audioUrl"] = "https://raw.githubusercontent.com/yugusu704-lang/yasi/main/assets/demo/c18_t1_s1.mp3"
    data["localAudioPath"] = "assets/demo/c18_t1_s1.mp3"

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\nSuccessfully generated master audio: {final_mp3}")
    print(f"Total Duration: {total_dur_ms} ms ({total_dur_ms / 1000:.1f} s)")
    print(f"File Size: {os.path.getsize(final_mp3)} bytes")

    # Output formatted Dart code for default_data.dart
    print("\n=== Dart SubtitleSentence updates for default_data.dart ===")
    for s in data["sentences"]:
        print(f"        SubtitleSentence(")
        print(f"          index: {s['index']},")
        print(f"          startMs: {s['startMs']},")
        print(f"          endMs: {s['endMs']},")
        print(f"          textEn: '{s['textEn']}',")
        print(f"          textZh: '{s['textZh']}',")
        print(f"          keyWords: {s['keyWords']},")
        print(f"        ),")

if __name__ == "__main__":
    asyncio.run(main())
