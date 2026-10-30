#!/usr/bin/env python3
"""Suggest equivalent composite arrays for one manifest's displayConditions.

Read-only JSON output. This is not a general Forge manifest validator.
"""

import argparse
from dataclasses import dataclass
from itertools import product
import json
from pathlib import Path
import re
import sys

try:
    import yaml
except ImportError:
    raise SystemExit("Install this skill's requirements.txt in an isolated Python environment.") from None

OPERATORS = {"and", "or", "not"}
MAX_PREDICATES = 12
MAX_DEPTH = 20
MAX_CONDITION_NODES = 256
MAX_MANIFEST_BYTES = 1_048_576
PAGE_MODULES = {"jira:adminPage", "jira:globalPage", "jira:projectPage", "jira:projectSettingsPage"}


class AnalysisError(ValueError):
    """Ambiguous or malformed condition input."""


class UnsupportedInput(ValueError):
    """Input that should be left for manual review."""


class ConditionLoader(yaml.SafeLoader):
    """Compose the manifest, but construct Python values only for conditions."""

    def compose_node(self, parent, index):
        event = self.peek_event()
        node = super().compose_node(parent, index)
        if getattr(event, "anchor", None) or getattr(event, "tag", None):
            node.unsupported = True  # Includes aliases; never expand shared conditions.
        return node

    def construct_object(self, node, deep=False):
        if getattr(node, "unsupported", False):
            raise UnsupportedInput("Anchors, aliases and explicit tags in conditions require manual review.")
        return super().construct_object(node, deep=deep)

    def construct_mapping(self, node, deep=False):
        return {key: self.construct_object(value, deep=True) for key, value in mapping(node).items()}


# Resolve input scalars using YAML 1.2-style rules, not 1.1's yes/no or dates.
ConditionLoader.yaml_implicit_resolvers = {
    char: [(tag, pattern) for tag, pattern in resolvers
           if tag not in {"tag:yaml.org,2002:bool", "tag:yaml.org,2002:int",
                          "tag:yaml.org,2002:float", "tag:yaml.org,2002:timestamp"}]
    for char, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
}
ConditionLoader.add_implicit_resolver(
    "tag:yaml.org,2002:bool", re.compile(r"^(?:true|True|TRUE|false|False|FALSE)$"), list("tTfF")
)
ConditionLoader.add_implicit_resolver(
    "tag:yaml.org,2002:int", re.compile(r"^[-+]?(?:[0-9]+|0o[0-7]+|0x[0-9a-fA-F]+)$"), list("-+0123456789")
)
ConditionLoader.add_implicit_resolver(
    "tag:yaml.org,2002:float",
    re.compile(r"^[-+]?(?:(?:[0-9]+\.[0-9]*|\.[0-9]+)(?:[eE][-+]?[0-9]+)?|[0-9]+[eE][-+]?[0-9]+|\.(?:inf|Inf|INF|nan|NaN|NAN))$"),
    list("-+0123456789."),
)


def construct_int(loader, node):
    value = loader.construct_scalar(node)
    unsigned = value.lstrip("+-")
    base = 8 if unsigned.startswith("0o") else 16 if unsigned.startswith("0x") else 10
    return int(value, base)


ConditionLoader.add_constructor("tag:yaml.org,2002:int", construct_int)


class ConditionDumper(yaml.SafeDumper):
    """Quote strings that have special meanings in either YAML version."""


ConditionDumper.yaml_implicit_resolvers = {
    char: list(yaml.SafeDumper.yaml_implicit_resolvers.get(char, [])) + list(resolvers)
    for char, resolvers in ConditionLoader.yaml_implicit_resolvers.items()
}
ConditionDumper.add_implicit_resolver("tag:yaml.org,2002:bool", re.compile(r"^[yYnN]$"), list("yYnN"))


def mapping(node):
    """Read only one mapping level; do not decode unrelated values."""
    if not isinstance(node, yaml.MappingNode):
        raise AnalysisError("Expected a mapping on the path to displayConditions.")
    if getattr(node, "unsupported", False):
        raise UnsupportedInput("Shared or tagged condition locations require manual review.")
    result = {}
    for key, value in node.value:
        if key.value == "<<":
            raise UnsupportedInput("YAML merge keys in condition locations require manual review.")
        if key.tag != "tag:yaml.org,2002:str":
            raise AnalysisError("Condition locations and parameter keys must be strings.")
        if key.value in result:
            raise AnalysisError(f"Duplicate YAML key {key.value!r} at line {key.start_mark.line + 1}.")
        result[key.value] = value
    return result


def atom_id(name, value):
    return json.dumps([name, value], sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def children(value):
    return value if isinstance(value, list) else [value]


def validate_condition(node):
    """Validate Boolean structure, not product-specific leaf schemas."""
    atoms = []
    size = 0

    def visit(current, depth):
        nonlocal size
        if depth > MAX_DEPTH:
            raise UnsupportedInput(f"Expression exceeds depth {MAX_DEPTH}; left unchanged.")
        if not isinstance(current, dict) or not current:
            raise AnalysisError("Each condition and operator array item must be a non-empty mapping.")
        size += len(current)
        if size > MAX_CONDITION_NODES:
            raise UnsupportedInput(f"Expression exceeds {MAX_CONDITION_NODES} condition entries; left unchanged.")
        for name, value in current.items():
            if not isinstance(name, str):
                raise AnalysisError("Condition names must be strings.")
            if name in OPERATORS:
                if isinstance(value, list) and not value:
                    raise UnsupportedInput("Empty operator arrays require manual review; left unchanged.")
                for child in children(value):
                    visit(child, depth + 1)
            else:
                atoms.append(atom_id(name, value))
    visit(node, 0)
    if len(set(atoms)) > MAX_PREDICATES:
        raise UnsupportedInput(f"Expression exceeds {MAX_PREDICATES} distinct predicates; equivalence not checked.")
    return atoms


@dataclass(frozen=True)
class Expr:
    kind: str
    args: tuple = ()
    atom: str = ""


def to_expr(node, inherited="and"):
    """Resolve inherited object folding BEFORE applying Boolean identities."""
    terms = []
    for name, value in node.items():
        if name not in OPERATORS:
            terms.append(Expr("atom", atom=atom_id(name, value)))
            continue
        operator = "or" if name == "not" else name
        group = Expr(operator, tuple(to_expr(child, operator) for child in children(value)))
        terms.append(Expr("not", (group,)) if name == "not" else group)
    return Expr(inherited, tuple(terms))


def simplify(expr):
    """Flatten like operators, singleton grouping and double negation; keep leaves."""
    if expr.kind == "atom":
        return expr
    args = tuple(simplify(arg) for arg in expr.args)
    if expr.kind == "not":
        return args[0].args[0] if args[0].kind == "not" else Expr("not", args)
    flattened = tuple(child for arg in args for child in (arg.args if arg.kind == expr.kind else (arg,)))
    return flattened[0] if len(flattened) == 1 else Expr(expr.kind, flattened)


def render(expr, root=False):
    if expr.kind == "atom":
        name, value = json.loads(expr.atom)
        return {name: value}
    if expr.kind == "not" and expr.args[0].kind == "or":
        return {"not": [render(arg) for arg in expr.args[0].args]}
    items = [render(arg) for arg in expr.args]
    if root and expr.kind == "and":  # Keep implicit AND only without key collisions.
        merged = {}
        for item in items:
            if merged.keys() & item.keys():
                break
            merged.update(item)
        else:
            return merged
    return {expr.kind: items}


def evaluate(node, assignment, inherited="and"):
    """Independent of the rewriter: children inherit the operator; NOT is NOR."""
    values = []
    for name, value in node.items():
        if name not in OPERATORS:
            values.append(assignment[atom_id(name, value)])
        else:
            operator = "or" if name == "not" else name
            fold = all if operator == "and" else any
            result = fold(evaluate(child, assignment, operator) for child in children(value))
            values.append(not result if name == "not" else result)
    return (all if inherited == "and" else any)(values)


def verify_equivalent(before, after):
    before_atoms = validate_condition(before)
    after_atoms = validate_condition(after)
    if before_atoms != after_atoms:
        return False, 0  # Includes multiplicity, order, types and parameters.
    unique = sorted(set(before_atoms))
    checked = 0
    for bits in product((False, True), repeat=len(unique)):
        assignment = dict(zip(unique, bits))
        checked += 1
        if evaluate(before, assignment) != evaluate(after, assignment):
            return False, checked
    return True, checked


def complexity(node):
    count = depth = 0
    for name, value in node.items():
        if name in OPERATORS:
            count += 1
            for child in children(value):
                child_count, child_depth = complexity(child)
                count += child_count
                depth = max(depth, 1 + child_depth)
    return count, depth


def contains_operator_array(node):
    return any(name in OPERATORS and (isinstance(value, list) or contains_operator_array(value))
               for name, value in node.items())


def analyze_condition(condition):
    try:
        atoms = validate_condition(condition)
        candidate = render(simplify(to_expr(condition)), root=True)
        old_count, old_depth = complexity(condition)
        new_count, new_depth = complexity(candidate)
        if (new_count > old_count or new_depth > old_depth
                or (new_count, new_depth) == (old_count, old_depth)
                or not contains_operator_array(candidate)):
            return {"status": "no-change", "reason": "No supported array rewrite reduces operator count or nesting."}
        candidate_yaml = yaml.dump({"displayConditions": candidate}, Dumper=ConditionDumper, sort_keys=False, allow_unicode=True).rstrip()
        emitted = yaml.load(candidate_yaml, Loader=ConditionLoader)["displayConditions"]
        valid, checked = verify_equivalent(condition, emitted)
        if not valid:
            return {"status": "skipped", "reason": "Candidate failed equivalence or leaf-preservation checks."}
        return {"status": "suggestion", "reason": "Replace redundant grouping with composite arrays.",
                "after": candidate, "after_yaml": candidate_yaml,
                "equivalence": {"verified": True, "assignments_checked": checked, "distinct_predicates": len(set(atoms))}}
    except UnsupportedInput as exc:
        return {"status": "skipped", "reason": str(exc)}
    except (AnalysisError, TypeError, ValueError, yaml.YAMLError, RecursionError) as exc:
        return {"status": "error", "reason": str(exc)}


def condition_locations(node, module_type, path):
    """Visit module/page conditions, never arbitrary configuration or leaf values."""
    fields = mapping(node)
    for key, value in node.value:
        if key.value == "displayConditions":
            yield value, path + ["displayConditions"], key.start_mark.line + 1
    if module_type in PAGE_MODULES:
        for field in ("pages", "sections"):
            nested = fields.get(field)
            if isinstance(nested, yaml.SequenceNode):
                if getattr(nested, "unsupported", False):
                    raise UnsupportedInput("Shared or tagged page locations require manual review.")
                for index, item in enumerate(nested.value):
                    if isinstance(item, yaml.MappingNode):
                        yield from condition_locations(item, module_type, path + [field, index])


def analyze_file(path):
    path = Path(path)
    result = {"path": str(path), "status": "analyzed", "findings": []}
    loader = None
    try:
        if path.stat().st_size > MAX_MANIFEST_BYTES:
            raise UnsupportedInput("Manifest exceeds the 1 MiB analysis limit.")
        loader = ConditionLoader(path.read_text(encoding="utf-8"))
        manifest = mapping(loader.get_single_node())
        if "modules" not in manifest:
            raise UnsupportedInput("Not a Forge manifest: no modules key; skipped.")
        for module_type, entries in mapping(manifest["modules"]).items():
            if not isinstance(entries, yaml.SequenceNode):
                continue  # Other manifest validation belongs to forge lint.
            if getattr(entries, "unsupported", False):
                raise UnsupportedInput("Shared or tagged module locations require manual review.")
            for index, module in enumerate(entries.value):
                if not isinstance(module, yaml.MappingNode):
                    continue
                key = mapping(module).get("key")
                for node, location, line in condition_locations(module, module_type, ["modules", module_type, index]):
                    finding = {"module_type": module_type, "module_key": key.value if isinstance(key, yaml.ScalarNode) else None,
                               "location": location, "line": line}
                    try:
                        if not module_type.startswith(("jira:", "jiraServiceManagement:")):
                            raise UnsupportedInput("Only Jira/JSM condition rewrites are supported; product rules differ.")
                        finding.update(analyze_condition(loader.construct_object(node, deep=True)))
                    except UnsupportedInput as exc:
                        finding.update(status="skipped", reason=str(exc))
                    except (AnalysisError, yaml.YAMLError, ValueError, RecursionError) as exc:
                        finding.update(status="error", reason=str(exc))
                    result["findings"].append(finding)
    except UnsupportedInput as exc:
        result.update(status="skipped", reason=str(exc), findings=[])
    except (OSError, UnicodeError, yaml.YAMLError, ValueError, RecursionError) as exc:
        result.update(status="error", reason=str(exc), findings=[])
    finally:
        if loader is not None:
            loader.dispose()
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="Path to one Forge manifest file")
    result = analyze_file(parser.parse_args(argv).manifest)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return int(result["status"] == "error" or any(f["status"] == "error" for f in result["findings"]))


if __name__ == "__main__":
    sys.exit(main())
