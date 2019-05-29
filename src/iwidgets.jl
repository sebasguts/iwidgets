module iwidgets

using IJulia

using UUIDs

abstract type AbstractWidget end

mutable struct Widget <: AbstractWidget
    comm
    display_message
    properties
end

widget_registry = Dict()

function Base.setproperty!(widget::AbstractWidget,name::Symbol,x::Any)
    comm = getfield(widget,:comm)
    IJulia.CommManager.send_comm(comm,
        Dict(
            "method" => "update",
            "state" => Dict(
                string(name) => x
            )
        )
    )
    getfield(widget,:properties)[name] = x
end

function Base.getproperty(widget::AbstractWidget,name::Symbol)
    getfield(widget,:properties)[name]
end

function update_handler(msg)
    global widget_registry
    if haskey(msg.content["data"], "method") && msg.content["data"]["method"] == "update"
        widget = widget_registry[msg.content["comm_id"]]
        for name in keys( msg.content["data"]["state"] )
            getfield(widget, :properties)[Symbol(name)] = msg.content["data"]["state"][name]
        end
        return true
    end
    return false
end



function my_callback(x)

    comm_id = x.content["comm_id"]
    comm = IJulia.CommManager.comms[comm_id]
    IJulia.CommManager.send_comm(comm,Dict(
        "method" => "update",
        "state" => Dict(
        "description" => "bar"
    )   )   )

    global widget_registry
    
    getfield(widget_registry[comm_id],:properties)[:description] = "bar"

    # IJulia.send_ipython(IJulia.publish[],msg_pub(IJulia.execute_msg,"display_data",Dict( "data" => Dict( "text/plain" => comm_id))))
end

function extend_callback( callback_func )
    return function( x )
        if update_handler( x )
            return
        end
        callback_func( x )
    end
end


function Widget(;kwargs...)

    model_id = string(uuid4())

    comm_data = Dict(
        "state" => Dict(
            "_model_module" => "@jupyter-widgets/base",
            "_model_module_version" => "1.1.0",
            "_model_name" => "LayoutModel",
            "_view_module" => "@jupyter-widgets/base",
            "_view_module_version" => "1.1.0",
            "_view_name" => "LayoutView"
        )
    )

    model_comm = IJulia.CommManager.Comm(
        "jupyter.widget",
        model_id,
        data = comm_data,
        metadata = Dict( "version" => "2.0.0" )
    )

    layout_id = string(uuid4())

    comm_data = Dict(
        "state" => Dict(
            "_model_module" => "@jupyter-widgets/controls",
            "_model_module_version" => "1.4.0",
            "_model_name" => "ButtonStyleModel",
            "_view_module" => "@jupyter-widgets/base",
            "_view_module_version" => "1.1.0",
            "_view_name" => "StyleView"
        )
    )

    comm = IJulia.CommManager.Comm(
        "jupyter.widget",
        layout_id,
        data = comm_data,
        metadata = Dict( "version" => "2.0.0" )
    )

    button_id = string(uuid4())

    comm_data = Dict(
        "state" => Dict{Union{Symbol,String},Any}(
            kwargs...,
            "layout" => "IPY_MODEL_" * layout_id,
            "style" => "IPY_MODEL_" * model_id,
            "_model_module" => "@jupyter-widgets/controls",
            "_model_module_version" => "1.4.0",
            "_model_name" => "ButtonModel",
            "_view_module" => "@jupyter-widgets/controls",
            "_view_module_version" => "1.4.0",
            "_view_name" => "ButtonView"
        )
    )

    comm = IJulia.CommManager.Comm(
        "jupyter.widget",
        button_id,
        true,
        extend_callback( my_callback ),
        data = comm_data,
        metadata = Dict( "version" => "2.0.0" )
    )

    data = Dict{String,Any}()

    data["text/plain"] = "foo"

    data["application/vnd.jupyter.widget-view+json"] = Dict{String,Any}(
        "version_major" => 2,
        "version_minor" => 0,
        "model_id" => comm.id
    )

    
    # header = msg_header(execute_message,"iopub")
    
    # msg = msg_pub(IJulia.execute_msg,"display_data",Dict( "data" => data ) )
    
    x = Widget(comm,Dict( "data" => data ),Dict{Union{Symbol,String},Any}(kwargs...))

    global widget_registry
    widget_registry[comm.id] = x

    return x

end

function mydisplay(x)
    
    IJulia.send_ipython(IJulia.publish[],msg_pub(IJulia.execute_msg,"display_data",getfield(x,:display_message)))

end

end # module
