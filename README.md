abbrabot
========

論文誌からタイトルとアブストを引っ張ってきて、Microsoft Translatorで機械翻訳し、アブストの第一文目、HTMLタグ、ひらがな、カタカナの一部、その他地味な文字を消し、タイトルとアブストの間に本文へのリンクを貼って、140文字以降はきれいに消したモノをつぶやくtwitterボット。https://twitter.com/abbrabot

使い方
------

Twitter の API を使うための

* consumer_key
* consumer_secret
* oauth_token
* oauth\_token\_secret
 
の4つの文字列を書いたファイル(hoge.txt とする)と、
Microsoft Translator API を使うための

* クライアントID
* 顧客の秘密

の2つの文字列を書いたファイル(fuga.txt とする)を用意し、

    $ ruby abbrabot.rb hoge.txt fuga.txt

で実行すると、動かせる。
