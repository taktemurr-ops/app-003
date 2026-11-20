#!/usr/bin/env python3
"""Idempotently applies native settings to the generated android/ and ios/
projects (AdMob app ids, display name, localizations, iOS minimum version).

Real AdMob app ids are read from ADMOB_APP_ID_ANDROID / ADMOB_APP_ID_IOS.
Defaults are Google's public test app ids, which never serve real ads.
"""
import os, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME = "Hydration Universe"
ANDROID_APP_ID = os.environ.get("ADMOB_APP_ID_ANDROID") or "ca-app-pub-3940256099942544~3347511713"
IOS_APP_ID = os.environ.get("ADMOB_APP_ID_IOS") or "ca-app-pub-3940256099942544~1458002511"

def android():
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        return
    text = manifest.read_text()
    if "com.google.android.gms.ads.APPLICATION_ID" not in text:
        meta = ('\n        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"'
                f' android:value="{ANDROID_APP_ID}"/>')
        text = re.sub(r"(<application[^>]*>)", r"\1" + meta, text, count=1)
    text = re.sub(r'android:label="[^"]*"', f'android:label="{NAME}"', text, count=1)
    manifest.write_text(text)
    print("android manifest configured")

def ios():
    plist = ROOT / "ios/Runner/Info.plist"
    if not plist.exists():
        return
    text = plist.read_text()
    additions = ""
    if "GADApplicationIdentifier" not in text:
        additions += f"\t<key>GADApplicationIdentifier</key>\n\t<string>{IOS_APP_ID}</string>\n"
        additions += ("\t<key>SKAdNetworkItems</key>\n\t<array>\n\t\t<dict>\n"
                      "\t\t\t<key>SKAdNetworkIdentifier</key>\n\t\t\t<string>cstr6suwn9.skadnetwork</string>\n"
                      "\t\t</dict>\n\t</array>\n")
    if "CFBundleLocalizations" not in text:
        additions += ("\t<key>CFBundleLocalizations</key>\n\t<array>\n"
                      "\t\t<string>en</string>\n\t\t<string>tr</string>\n\t\t<string>ar</string>\n\t</array>\n")
    if additions:
        idx = text.rfind("</dict>")
        text = text[:idx] + additions + text[idx:]
    text = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{NAME}\2", text)
    plist.write_text(text)
    podfile = ROOT / "ios/Podfile"
    if podfile.exists():
        pod = podfile.read_text()
        pod = re.sub(r"^#?\s*platform :ios, '[0-9.]+'", "platform :ios, '15.0'", pod, flags=re.M)
        podfile.write_text(pod)
    print("ios configured")

android()
ios()
