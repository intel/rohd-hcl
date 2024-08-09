# ROHD-HCL Flutter Configuration App

This is a web app that allows RTL generation (SystemVerilog) based on the specific configuration.

## Widget Tree

```mermaid
flowchart TD;
    HCLAPP:material_widget-->HCLPage:register_cubit-->HCLView-->MainPage --> ComponentSideBar:Nav & SVGenerator:Content
```

----------------

Copyright (C) 2023-2024 Intel Corporation
SPDX-License-Identifier: BSD-3-Clause
