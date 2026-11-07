package com.lil.miniscript;

import java.util.List;
import java.util.Map;

class LangClass implements LangCallable {
    final String name;
    private final Map<String, UserFunction> methods;

    LangClass(String name, Map<String, UserFunction> methods) {
        this.name = name;
        this.methods = methods;
    }

    UserFunction findMethod(String name) {
        return methods.get(name);
    }

    @Override
    public String toString() { return name; }

    @Override
    public int arity() {
        UserFunction initializer = findMethod("init");
        return initializer == null ? 0 : initializer.arity();
    }

    @Override
    public Object call(Interpreter interpreter, List<Object> arguments) {
        LangInstance instance = new LangInstance(this);
        UserFunction initializer = findMethod("init");
        if (initializer != null) {
            initializer.bind(instance).call(interpreter, arguments);
        }
        return instance;
    }
}
