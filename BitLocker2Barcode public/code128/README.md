# Powershell-Barcodes

Barcode Creation using Powershell

**Supported Barcodes**
* Code 128 (Length Optimization WIP)

**Status**  
Work in progress. Use at your own risk. The code is short though, so fully understanding what it does before using it should be relatively easy.

## Description

Need to create a barcode? Need a reference implementation to convert into your language of choice? Hopefully you can find it here. 

This library relies on barcode fonts. Producing barcode images is currently beyond the scope of this repo but something that may be added in the future.

With a font such as [Libre Barcode 39](https://fonts.google.com/specimen/Libre+Barcode+39) or [Libre Barcode 39 Text](https://fonts.google.com/specimen/Libre+Barcode+39+Text), this is super easy, barely an inconvenience. All you need is to enclose your text with asterisks to mark the beginning and end of the barcode. What you lack is information density. Barcodes are longer than they otherwise could be.

Barcode128 can produce shorter barcodes but is a bit more complicated. There are 3 code sets (A, B, C) each of which has their own start value. In addition, a checksum needs computed for the values included. Barcode 128C, in particular, can be used to efficiently encode long strings of digits which requires additional computation. And you can even use multiple codesets within the same barcode. Crazy stuff.

## Usage
Run the text you wish to convert into a barcode against `Get-Code128String`. The resulting text can be rendered in barcode form using a barcode font such as Libre Barcode.

**Google Font Preview Links:**
* [Libre Barcode 128](https://fonts.google.com/specimen/Libre+Barcode+128)
* [Libre Barcode 128 Text](https://fonts.google.com/specimen/Libre+Barcode+128+Text)

## Kudos

A big thanks to the creator of [Libre Barcode](https://github.com/graphicore/librebarcode)!

## Reading Material

https://en.wikipedia.org/wiki/Code_128