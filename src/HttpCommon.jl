__precompile__()

module HttpCommon

using Compat; import Compat.String
import URIParser: URI, unescape

export Headers, Request, Cookie, Response,
       escapeHTML, parsequerystring


# All HTTP status codes, as a Dict of code => description
export STATUS_CODES
include("status.jl")


"""
`Headers` represents the header fields for an HTTP request.
"""
typealias Headers Dict{AbstractString,AbstractString}
headers() = Headers(
    "Server"            => "Julia/$VERSION",
    "Content-Type"      => "text/html; charset=utf-8",
    "Content-Language"  => "en",
    "Date"              => Dates.format(now(Dates.UTC), Dates.RFC1123Format) )


"""
A `Request` represents an HTTP request sent by a client to a server.
It has five fields:

* `method`: an HTTP methods string (e.g. "GET")
* `resource`: the resource requested (e.g. "/hello/world")
* `headers`: see `Headers` above
* `data`: the request data as a vector of bytes
"""
type Request
    method::String      # HTTP method string (e.g. "GET")
    resource::String    # Resource requested (e.g. "/hello/world")
    headers::Headers
    data::Vector{UInt8}
    uri::URI
end
Request() = Request("", "", Headers(), UInt8[], URI(""))
Request(method, resource, headers, data) = Request(method, resource, headers, data, URI(""))

Base.show(io::IO, r::Request) = print(io, "Request(", r.uri, ", ",
                                        length(r.headers), " headers, ",
                                        sizeof(r.data), " bytes in body)")


"""
A `Cookie` represents an HTTP cookie. It has three fields:
`name` and `value` are strings, and `attrs` is dictionary
of pairs of strings.
"""
type Cookie
    name::String
    value::String
    attrs::Dict{String, String}
end
Cookie(name, value) = Cookie(name, value, Dict{String, String}())
Base.show(io::IO, c::Cookie) = print(io, "Cookie(", c.name, ", ", c.value,
                                        ", ", length(c.attrs), " attributes)")


"""
A `Response` represents an HTTP response sent to a client by a server.
It has six fields:

* `status`: HTTP status code (see `STATUS_CODES`) [default: `200`]
* `headers`: `Headers` [default: `HttpCommmon.headers()`]
* `cookies`: Dictionary of strings => `Cookie`s
* `data`: the request data as a vector of bytes [default: `UInt8[]`]
* `finished`: `true` if the `Reponse` is valid, meaning that it can be
  converted to an actual HTTP response [default: `false`]
* `requests`: the history of requests that generated the response.
  Can be greater than one if a redirect was involved.

Response has many constructors - use `methods(Response)` for full list.
"""
type Response
    status::Int
    headers::Headers
    cookies::Dict{String, Cookie}
    data::Vector{UInt8}
    request::Nullable{Request}
    history::Vector{Response}

    # Deprecated fields
    finished::Bool
    requests::Vector{Request}
end
# If a Response is instantiated with all of fields except for `finished`,
# `finished` will default to `false`.
typealias HttpData Union{Vector{UInt8}, AbstractString}
Response(s::Int, h::Headers, d::HttpData) =
  Response(s, h, Dict{String, Cookie}(), d, Nullable(), Response[], false, Request[])
Response(s::Int, h::Headers)              = Response(s, h, UInt8[])
Response(s::Int, d::HttpData)             = Response(s, headers(), d)
Response(d::HttpData, h::Headers)         = Response(200, h, d)
Response(d::HttpData)                     = Response(d, headers())
Response(s::Int)                          = Response(s, headers(), UInt8[])
Response()                                = Response(200)

function Base.show(io::IO, r::Response)
    print(io, "Response(", r.status, " ", STATUS_CODES[r.status], ", ",
          length(r.headers)," headers, ",
          sizeof(r.data)," bytes in body)")
end


"""
escapeHTML(i::AbstractString)

Returns a string with special HTML characters escaped: &, <, >, ", '
"""
function escapeHTML(i::AbstractString)
    # Refer to http://stackoverflow.com/a/7382028/3822752 for spec. links
    o = replace(i, "&", "&amp;")
    o = replace(o, "\"", "&quot;")
    o = replace(o, "'", "&#39;")
    o = replace(o, "<", "&lt;")
    o = replace(o, ">", "&gt;")
    return o
end


"""
parsequerystring(query::AbstractString)

Convert a valid querystring to a Dict:

    q = "foo=bar&baz=%3Ca%20href%3D%27http%3A%2F%2Fwww.hackershool.com%27%3Ehello%20world%21%3C%2Fa%3E"
    parsequerystring(q)
    # Dict{String,String} with 2 entries:
    #   "baz" => "<a href='http://www.hackershool.com'>hello world!</a>"
    #   "foo" => "bar"
"""
function parsequerystring{T<:AbstractString}(query::T)
    q = Dict{AbstractString,AbstractString}()
    length(query) == 0 && return q
    for field in split(query, "&")
        keyval = split(field, "=")
        length(keyval) != 2 && throw(ArgumentError("Field '$field' did not contain an '='."))
        q[unescape(keyval[1])] = unescape(keyval[2])
    end
    q
end


end # module HttpCommon
