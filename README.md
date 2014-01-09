abbrabot
========

論文誌からタイトルとアブストを引っ張ってきて、Excite翻訳にかけ、アブストの第一文目、HTMLタグ、ひらがな、カタカナの一部、その他地味な文字を消し、タイトルとアブストの間に本文へのリンクを貼って、140文字以降はきれいに消したモノをつぶやくtwitterボット。https://twitter.com/abbrabot

使い方
------

* consumer_key
* consumer_secret
* oauth_token
* oauth\_token\_secret
 
の4つの文字列を書いたファイル(hoge.txt とする)を用意し

    $ ruby abbrabot.rb hoge.txt

で実行すると、動かせる。
