# [@esmodtree/cli-v1.2.1](https://github.com/rlaffers/esmodtree/compare/@esmodtree/cli@1.2.0...@esmodtree/cli@1.2.1) (2026-04-23)


### Bug Fixes

* **cli:** include re-exporting modules in the output with --symbol opt is used ([19657cd](https://github.com/rlaffers/esmodtree/commit/19657cdee21f987d993d336b09159fcdd2bcd13f))

# [1.2.0](https://github.com/rlaffers/esmodtree/compare/@esmodtree/cli@1.1.0...@esmodtree/cli@1.2.0) (2026-04-21)


### Features

* **nvim:** add internal mappings for sending symbols to cli ([b8e0031](https://github.com/rlaffers/esmodtree/commit/b8e0031e9e0f3d172f6aba27edfca0e1805a8cff))

# [1.1.0](https://github.com/rlaffers/esmodtree/compare/@esmodtree/cli@1.0.0...@esmodtree/cli@1.1.0) (2026-04-21)


### Features

* **cli:** add a --symbol option ([eb2e425](https://github.com/rlaffers/esmodtree/commit/eb2e42501556ca18cf3240326934b4d0b8a760e4))

# 1.0.0 (2026-04-17)


### Bug Fixes

* filter invalid source dirs from tsconfig include patterns ([b98691e](https://github.com/rlaffers/esmodtree/commit/b98691e817e083b1841333c2591c532985598f96))
* include typescript as a peer dep to allow dlx execution ([f63044a](https://github.com/rlaffers/esmodtree/commit/f63044a2c46e010c8c57115ad65f2247910525a8))


### Features

* add --depth, --exclude, --root, and --json CLI flags ([9344a45](https://github.com/rlaffers/esmodtree/commit/9344a45c70bdb428e91a138a4c182b2b510b8bd5))
* add barrel and dynamic import markers ([04b8b60](https://github.com/rlaffers/esmodtree/commit/04b8b60c36f0750ea1fe2ac228379a619fb7bfba))
* add project detection, root markers, and colored output ([c83420f](https://github.com/rlaffers/esmodtree/commit/c83420f1f928ab06f494e152c0d8c2730122c7e0))
* add tsconfig detection, path alias resolution, and --debug flag ([84e21bc](https://github.com/rlaffers/esmodtree/commit/84e21bce30746eda28f76895497818a826402c33))
* **cli:** add --upup command to rever up tree in a reverse order ([384ebbe](https://github.com/rlaffers/esmodtree/commit/384ebbe58b5297d383320732f55ac4d3934feafb))
* implement --down mode with ASCII tree output ([9b11ce1](https://github.com/rlaffers/esmodtree/commit/9b11ce1183fa154acc79b595a5896f671858746d))
* implement --up mode with ASCII tree output ([3ebc2aa](https://github.com/rlaffers/esmodtree/commit/3ebc2aa64b20a74011a9f56809f0c21f60f0ca0f))
* **tree:** colorize filenames ([0a7f20c](https://github.com/rlaffers/esmodtree/commit/0a7f20c6cde182daf41c3409331cc7dea6c281c4))
