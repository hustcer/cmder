# cmder

[English](README.md) | [简体中文](README.zh.md)

`hustcer/cmder` 是 MoonBit 的声明式命令行构建库，基于 `moonbitlang/core/argparse`。

**本项目 fork 自 [mizchi/admiral](https://github.com/mizchi/admiral)，并在其基础上进行修改和维护。** 感谢 mizchi 和上游贡献者提供的设计与实现；上游项目的设计灵感来自 [gunshi](https://github.com/kazupon/gunshi)。

- 支持根命令、多层子命令，以及可以传播错误的回调。
- 支持字符串、Boolean、经过校验的 Int32 选项，以及位置参数。
- 显式声明供后代共享的 global 选项，其他参数保持局部作用域。
- 不可变的命令定义和解析结果，提供参数来源信息。
- 生成帮助、版本、JSON 定义以及 Bash/Zsh/Fish 补全脚本。

## 与 admiral 0.1.2 的差异

fork 以来，cmder 的包名和 API 已发生变化。迁移时需要更新导入路径，并按当前接口调整代码：

- 选项辅助函数的 `short` 和 `default` 直接接受值，命令定义和上下文为只读。
- 根命令可以包含回调和位置参数；回调可以向应用传播错误。
- 选项默认为局部选项；设置 `global=true` 可供后代命令使用。必填局部选项只在其所属命令被选中时生效。
- `parse` 返回结构化结果，不执行回调或进行进程 I/O。解析结果可供检查、覆盖和分发，并可通过 `source_of` 查询参数来源。
- 构建时校验命令定义，解析时校验整数选项的格式和 Int32 范围。
- JSON 定义包含位置参数的顺序和数量信息；生成的帮助和 shell 补全反映命令及选项的作用域。

当前用法参见下文，各版本的具体变更参见 [CHANGELOG.md](CHANGELOG.md)。

## 安装

```sh
moon add hustcer/cmder
```

在使用它的包的 `moon.pkg` 中添加导入：

```text
import {
  "hustcer/cmder",
}
pkgtype(kind: "executable")
```

## 快速开始

单命令工具无需额外创建子命令。将下面的代码放入 `main.mbt`：

<!-- cmder-example {"id":"quick-start","kind":"program","args":["-n","Ada"],"stdout":"Hello, Ada!\n","fail_args":["-n","Ada","--count","bad"],"error":"invalid integer for 'count': 'bad'"} -->

```moonbit
///|
fn main raise {
  let app = @cmder.cli(
    name="hello",
    version="1.0.0",
    options=[
      @cmder.string("name", short='n', required=true),
      @cmder.int("count", short='c', default=1),
      @cmder.bool("loud", short='l'),
    ],
    examples=["hello -n Alice", "hello -n Bob -l -c 2"],
    run=ctx => {
      let name = ctx.get_string_required("name")
      let count = ctx.get_int_required("count")
      for _ in 0..<count {
        let message = "Hello, \{name}!"
        println(if ctx.get_bool("loud") { message.to_upper() } else { message })
      }
    },
  )
  app.run_or_exit()
}
```

```text
$ hello -n Alice
Hello, Alice!
$ hello -n Bob -l -c 2
HELLO, BOB!
HELLO, BOB!
```

`--help` 和 `--version` 自动生成。应用回调的类型为 `(Context) -> Unit raise`：参数读取错误及业务错误通过 dispatch 和 run 原样传播。`run_or_exit` 输出错误并以状态码 1 退出，帮助/版本以状态码 0 退出；需要自定义输出的宿主使用 `run` 或 `parse`。错误在 native 和 JS 上写入 stderr；当前 wasm-gc 运行时会退回 stdout。

`cli` 在构建时验证完整定义树。名称非法、参数/短选项/子命令重名、位置参数顺序错误，以及与继承 global 参数冲突，都会抛出 `CliError::InvalidDefinition`。因此示例使用 `fn main raise`。

应用名和子命令名使用单个单词，允许 ASCII 字母、数字、下划线、连字符、点号、加号及可打印的非 ASCII 字符；拒绝空白、控制字符及前导连字符。`tool.exe`、`中文工具` 和 `release.v2+` 均合法。选项及位置参数标识符使用 ASCII 字母、数字、下划线和连字符，不允许前导连字符。短选项使用一个 ASCII 字母、数字或下划线。补全函数标识符独立于命令拼写编码生成；描述仍可使用任意文本。

## 选项与位置参数

<!-- cmder-example {"id":"options","kind":"pure","binds":["options"]} -->

```moonbit
let options = [
  @cmder.string("config", short='f', required=true),
  @cmder.string("host", default="localhost"),
  @cmder.int("port", short='p', default=3000),
  @cmder.bool("verbose", short='v', global=true),
]
```

`short` 和 `default` 直接接受对应的值。字符串/整数选项设置默认值后，即使同时指定 `required=true`，也允许省略。Boolean 开关始终可省略，初始值为 false。辅助函数创建归一化、只读的 `OptionDef`，不再支持直接构造记录。`OptionKind` 的 `StringOpt` 保存 `String?` 默认值，`IntOpt` 保存 `Int32?` 默认值，`BoolOpt` 不携带值默认值。未设置的短选项以 `None` 表示。

`parse` 和 `run` 始终校验整数选项：允许带负号的十进制 Int32，范围为 -2147483648 到 2147483647。前导零没有位数限制。负数支持 `--delta -1`、`-d -1` 和 `--delta=-1`。整数选项不会吞掉后续开关或 `--`，`--count --help` 会显示帮助。`get_string` 仍能读取原始写法。正数、业务范围和参数关系由应用自行校验。

根命令和子命令都支持 `positionals`。必填位置参数必须位于可选参数之前；除最后一个之外，每个位置参数最多接受一个值，最后一个默认接受剩余所有值。设置 `multiple=false` 可以将该参数限制为单值，包括最后一个；多余输入会导致解析失败：

<!-- cmder-example {"id":"positionals","kind":"raising","binds":["app"]} -->

```moonbit
let app = @cmder.cli(
  name="copy",
  positionals=[
    @cmder.positional("source", required=true),
    @cmder.positional("destinations"),
  ],
  run=ctx => {
    println(ctx.get_string_required("source"))
    println(ctx.get_strings("destinations").join(", "))
  },
)
```

`copy a.txt b.txt c.txt` 得到 `source="a.txt"` 和 `destinations=["b.txt", "c.txt"]`。

带子命令的命令可以包含可选位置参数，但不能包含必填位置参数：argparse 会让该组合的子命令不可达，因此构建时会拒绝。开始读取位置参数后，再遇到子命令名会导致解析错误；在该名称前加入 `--` 可将其作为普通值，例如 `app x.txt -- go` 将两个单词都作为位置参数。

## 子命令与作用域

<!-- cmder-example {"id":"subcommands","kind":"raising","binds":["app"]} -->

```moonbit
let app = @cmder.cli(
  name="myapp",
  options=[@cmder.bool("verbose", short='v', global=true)],
  commands=[
    @cmder.command(
      name="db",
      options=[@cmder.string("region", default="west", global=true)],
      subcommands=[
        @cmder.command(name="migrate", options=[@cmder.bool("dry-run")], run=ctx => {
          if ctx.get_bool("verbose") {
            println("Starting migration")
          }
          println(ctx.get_string_required("region"))
          println(if ctx.get_bool("dry-run") { "Preview" } else { "Apply" })
        }),
      ],
    ),
  ],
)
```

Global 选项可以出现在声明层级及其任意后代层级。`myapp -v db migrate` 和 `myapp db migrate -v` 都可使用；`--region` 从进入 `db` 后开始可用。每个 global 参数只有一份定义，后代不能用相同名称或短选项重新定义或遮蔽它。显式输入优先于该参数的默认值。

其他参数保持局部作用域。回调只能读取选中命令的局部参数和继承的 global 参数。显式提供祖先局部选项后再选择子命令，将返回 `UnexpectedLocalArgument`，不再静默丢弃其值。祖先局部默认值不会泄漏。不同作用域的局部参数可以同名，但不会合并：根级 `string("count")` 不会为子级 `int("count")` 提供值。需要后代读取的选项应标记为 global。

局部 `required=true` 选项只在其所属命令被选中时必填。根级局部必填 `token` 不会阻止 `myapp db migrate` 执行。必填 global 在声明层级及其整个后代子树中都必填，并始终可由后代回调读取。缺少局部或 global 必填选项统一返回 `Failed(CliError::MissingOption(name))`，缺少必填位置参数返回 `MissingPositional(name)`。帮助及错误 Usage 保留必填标记。存在子命令时，帮助会列出局部必填选项并解释其作用域；可在 `cli` 或 `command` 上设置 `required_scope_notice="..."` 替换为本地化说明，空字符串可关闭说明。示例和说明只出现在命令自己的帮助中，不会混入父命令列表。后代自动示例包含必填祖先 global，即使叶子没有自己的参数。

只执行选中命令的回调。选择带回调的分组命令会执行该回调；选择更深的子命令时，只执行更深的回调。没有回调时，根命令调度抛出 `MissingCommand`，分组抛出 `MissingSubcommand`，叶子命令抛出 `MissingHandler`。

## 读取参数与错误处理

| 方法                        | 返回值                  | 含义                                  |
| --------------------------- | ----------------------- | ------------------------------------- |
| `get_bool(name)`            | `Bool`                  | 缺失时返回 false                      |
| `get_string(name)`          | `String?`               | 首个原始值，保留整数的原始写法        |
| `get_string_required(name)` | `String raise CliError` | 缺失时抛出 `MissingOption` / `MissingPositional` |
| `get_int(name)`             | `Int32? raise CliError` | 仅缺失返回 None，格式或范围错误会抛出 |
| `get_int_required(name)`    | `Int32 raise CliError`  | 缺失、格式错误和溢出都会抛出          |
| `get_strings(name)`         | `Array[String]`         | 所有值的独立副本，缺失时返回空数组    |
| `get_bool_checked(name)`    | `Bool raise CliError`   | 检查已声明的 Boolean 开关，缺失为 false |
| `get_string_checked(name)`  | `String? raise CliError`| 检查已声明的文本参数，缺失为 None     |
| `get_strings_checked(name)` | `Array[String] raise CliError` | 检查声明并返回所有值的独立副本 |
| `source_of(name)`           | `ValueSource?`          | 当前有效值的来源，缺失时返回 None     |

会抛错的 getter 检查可见参数名：拼写错误或超出作用域的名称抛出 `UnknownArgument`，Boolean 与文本类型不兼容时抛出 `ArgumentTypeMismatch`。三个不抛错的 getter 保留宽松的名称缺失行为，以兼容现有调用。文本 getter 可以读取字符串、整数原始写法及位置参数。`get_int` 和 `get_int_required` 也允许转换字符串及位置参数，格式非法抛出 `InvalidInteger(name, raw)`，溢出抛出 `IntegerOutOfRange(name, raw)`。只有已声明的参数缺失时才返回 None；必填 getter 区分 `MissingOption` 与 `MissingPositional`。

`CliError::message()` 和 `to_string()` 返回可直接展示的诊断。`ParseError(message)` 保留 argparse 的诊断文本和帮助，不应通过解析该文本判断机器可读的错误类别。业务回调错误保留原始错误类型，可由宿主集中处理。

## 解析、宿主检查与调度

`parse` 要求显式 argv，数组不包含可执行程序名。它不执行进程 I/O、不读取进程环境，也不执行回调，返回 `Parsed`、`Help`、`Version` 或 `Failed`。帮助、版本及结构性解析错误保持 argparse 相对于整数检查的原有优先级；只检查选中作用域的输入类型。

将以下流程放入允许传播错误的宿主函数。像下面这样由宿主控制进程退出时，需要导入 `moonbitlang/core/env`；独立工具可以直接使用 `run_or_exit` 的默认错误处理。

<!-- cmder-example {"id":"host-dispatch","kind":"raising","stdout":"3\n"} -->

```moonbit
let app = @cmder.cli(name="app", options=[@cmder.int("count", default=1)], run=ctx => {
  println(ctx.get_int_required("count"))
})
match app.parse(argv=["--count", "2"]) {
  Parsed(call) => {
    // Perform host checks before execution.
    let edited = call.with_overrides({
      "count": @cmder.ArgumentValue::Integer(3),
    })
    edited.dispatch()
  }
  Help(text) | Version(text) => println(text)
  Failed(error) => {
    eprintln(error.message())
    @env.exit(1)
  }
}
```

解析结果绑定选中命令的快照。`call.dispatch()` 无需另行配对 app，不重新解析，不执行帮助/版本 I/O，并原样传播回调错误。每次调用都会再次执行。`command_path` 是不包含应用名的只读列表，空路径选择根命令。`Context` 的存储私有，不再携带子命令树。

定义会将调用方提供的集合复制为只读数组。修改原始 argv 或 getter 返回的数组不会影响解析结果。宿主通过显式、原子的 `with_overrides` 覆盖参数：检查可见名称、参数类型及位置参数基数后返回新的 invocation。覆盖失败不会修改原结果。

| 覆盖值                               | 接受的参数                               |
| ------------------------------------ | ---------------------------------------- |
| `ArgumentValue::Text(text)`          | 字符串选项，或需要校验原始格式的整数选项 |
| `ArgumentValue::Integer(value)`      | 整数选项                                 |
| `ArgumentValue::Flag(value)`         | Boolean 开关                             |
| `ArgumentValue::Positionals(values)` | 位置参数，遵循必填及末尾多值约束         |

`call.source_of(name)` 和 `call.context.source_of(name)` 返回 `Argv`、`Default`、`Override` 或 None。`Env` 为底层来源模型保留；当前定义没有配置环境变量绑定。未改变的值保留原来源；被覆盖的值使用 `Override`，即使与 argv 值相等。清空可选位置参数会使其缺失，此时没有有效来源。`was_provided(name)` 仅在当前有效来源为 `Argv` 时返回 true。

`app.run()` 读取进程 argv，解析并调度，在帮助/版本请求时打印并以状态码 0 退出。`app.run(argv=[...])` 使用显式参数。解析及回调错误向调用方传播。`app.run_or_exit()` 额外负责输出失败并以状态码 1 退出。嵌入式宿主使用 `parse` 和 `call.dispatch()` 控制输出及退出状态。版本默认字符串为 `0.0.0`，正式工具应显式指定 `version`。

## 导出定义与补全

<!-- cmder-example {"id":"exports","kind":"raising","context":"subcommands","binds":["schema_text","schema_json","help","bash_script","zsh_script","fish_script"]} -->

```moonbit
let schema_text = app.render_schema()
let schema_json = app.render_schema_json()
let help = app.render_help(command_path=["db", "migrate"])
let bash_script = app.render_bash_completion()
let zsh_script = app.render_zsh_completion()
let fish_script = app.render_fish_completion()
```

这里的 CLI 描述格式不是标准 JSON Schema。它在参数所属命令中记录声明，包括 `global`、归一化的 `required`、有类型的默认值、位置参数和示例。整数默认值为 JSON 数字，字符串默认值为 JSON 字符串。根命令的位置参数/示例与子命令使用相同结构。位置参数元数据包含从零开始的 `index`、`min_args` 和 `max_args`（最后一个不限数量时为 null），消费者应按 `index` 排序。

嵌套帮助和补全包含继承的 global 参数，不包含祖先局部参数。内置帮助、根级版本和 `help` 主题均参与补全；应用定义的长、短拼写分别覆盖对应内置拼写。`--` 之后停止建议。本库不生成自定义参数值或位置参数文件名建议。

应用自行提供补全脚本/schema 导出入口，cmder 不自动添加 `--schema` 或补全子命令。应先完成应用构建，再处理导出请求。[可执行示例](src/examples/cli/main.mbt) 演示了 schema 导出。

```bash
source ./myapp.bash
```

```zsh
autoload -Uz compinit
compinit
source ./_myapp
```

```fish
source ./myapp.fish
```

`build_command(command)` 是显式的 argparse 互操作入口：验证定义并返回 `argparse.Command`，保留 argparse 对祖先必填参数的原始语义，不执行 cmder 的选中命令局部必填检查、整数输入检查或回调。普通消费者应使用 `CliApp::parse`。

## 从 0.3 迁移

| 旧用法                                         | 当前用法                                                              |
| ---------------------------------------------- | --------------------------------------------------------------------- |
| `default=Some(3)` / `default=Some("x")`        | `default=3` / `default="x"`                                           |
| `run=Some(fn(ctx) { ... })`                    | `run=(ctx) => { ... }`，允许向外传播错误                              |
| `app.run(argv=Some(args))`                     | `app.run(argv=args)`                                                  |
| `get_int_checked(name)`                        | `get_int(name)`，非法输入现在会抛错                                   |
| 隐式继承祖先参数                               | 将共享选项标记为 `global=true`                                        |
| 直接修改 Context/路径                          | `call.with_overrides(...)`                                            |
| `Context.subcommand` / `get_subcommand()`      | `Invocation.command_path`                                             |
| 公开定义记录字面量                             | 使用 `cli`、`command`、`string`、`int`、`bool`、`positional` 辅助函数 |
| `app.name`、`app.commands`、`app.root_options` | `app.root.name`、`app.root.subcommands`、`app.root.options`           |

`OptionType` 被携带有类型默认值的 `OptionKind` 替代。非法定义在构建阶段报错，不再等待第一次解析 argv。这些是有意的破坏性变更。

从 0.5.1 升级到 0.6：显式祖先局部选项现在报错，不再静默消失；需要共享时设置 `global=true`，或将选项传给其所属命令。缺少必填 global 选项现在返回 `MissingOption`，缺少必填位置参数返回 `MissingPositional`，二者在 0.5.1 中均为 `ParseError`。会抛错的 getter 现在拒绝未知名称及 Boolean/文本类型不匹配。现有不抛错的 getter 和末位位置参数的默认多值行为继续保留；`multiple=false`、严格 getter 和 `run_or_exit` 均为新增接口。0.3 之后未发布的开发接口 `validate_types` 和 `app.dispatch(call)` 已在 0.5 移除，它们不属于 v0.3.0。

## 本地开发

```sh
moon check --deny-warn --target native
moon test --target native
moon test --target js
moon test --target wasm-gc
moon run src/examples/cli --target native -- greet -n Alice
moon run src/examples/cli --target native -- db migrate up --dry-run
moon run src/examples/cli --target native -- --schema
nu scripts/check-cli.nu
nu scripts/check-completions.nu
nu scripts/check-readme.nu
```

进程检查覆盖 native/JS/wasm-gc。Shell 回归需要 Nushell 0.116+、Bash、Fish 和 Zsh，在干净 shell 中执行生成的脚本；Zsh 在非交互 ZLE 会话中捕获补全 widget 调用。CI 在 native 上运行 shell 检查。README 检查会比较两种语言的代码块及示例元数据，直接提取 MoonBit 示例并引用当前工作树，以禁止警告模式编译，在三个后端执行，并检查快速开始示例的错误退出状态。HTML `cmder-example` 标记声明每个示例的名称、变量及所需上下文示例；修改示例时须同步这些标记。CI 同样运行该检查。完整签名见[公开接口](src/pkg.generated.mbti)，新契约见[接口改进说明](docs/superpowers/specs/2026-11-05-cmder-interface.md)。

## 致谢与许可证

感谢 [mizchi/admiral](https://github.com/mizchi/admiral) 的作者及贡献者。本项目 fork 自该仓库，并在其实现上继续修改和维护。也感谢 [gunshi](https://github.com/kazupon/gunshi) 提供设计灵感，以及 MoonBit 的 `core/argparse` 提供参数解析。

许可证为 MIT，详见 [moon.mod](moon.mod)。
