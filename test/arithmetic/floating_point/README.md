
# How to generate test vectors using testfloat

```bash
git clone https://github.com/ucb-bar/berkeley-testfloat-3.git
git clone https://github.com/ucb-bar/berkeley-softfloat-3.git

cd berkeley-softfloat-3/build/Linux-x86_64-GCC/
make

cd berkeley-testfloat-3/build/Linux-x86_64-GCC/
make

testfloat_gen f32_to_f16

## 4FFFFDFE 7C00 05
## 5F7FFFFF 7C00 05
## CBFFF800 FC00 05
## 3AFFDEFF 17FF 01
## 5F7FFFFE 7C00 05
## C27FDFFB D3FF 01
```
