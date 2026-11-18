#!/bin/bash
# Entrypoint for the Jellyfin 12.0 PostgreSQL + rffmpeg brain.
#
# Adapted from JPVenson's (which the 10.11 brain inherits from its base
# image) for nintwentydo's provider. Two differences worth knowing:
#
#   - The plugin ASSEMBLY is Jellyfin.Plugin.Postgresql.dll, not
#     Jellyfin.Plugin.Pgsql.dll. The plugin NAME is "PostgreSQL" in both.
#   - nintwentydo resolves its connection from database.xml's
#     ConnectionString OR the POSTGRES_* env vars, so templating the XML
#     is belt-and-braces rather than mandatory (JPVenson ignored the XML
#     entirely and read env only). We still template it so the effective
#     configuration is visible in one file on the config volume.
#
# Recopying the plugin on every start is what keeps its ABI in step with
# the server across image upgrades — do not "optimise" it away.
set -euo pipefail

PLUGIN_DIR=/config/plugins/PostgreSQL
rm -rf "${PLUGIN_DIR}"
mkdir -p "${PLUGIN_DIR}"
cp -r /jellyfin-pgsql/plugin/* "${PLUGIN_DIR}/"

# Webtoon Reader and File Transformation, baked in for the same reason.
# Any other copy of the same plugin is removed first, found by the plugin
# GUID in its meta.json: the dashboard installs to "<Name>_<version>"
# folders (with spaces), and Jellyfin would otherwise keep whichever is
# newer and delete the baked, pinned one. Plugin settings live in
# /config/plugins/configurations and are kept. WEBTOON_READER_DEV_PLUGIN=1
# keeps a locally built reader in place (the plugin's dev stack).
install_baked_plugin() {
    local folder="$1" guid="$2" source="$3" dir
    for dir in /config/plugins/*/; do
        if [ -f "${dir}meta.json" ] && grep -Eqi "\"guid\": *\"${guid}\"" "${dir}meta.json"; then
            rm -rf "${dir}"
        fi
    done
    rm -rf "/config/plugins/${folder}"
    mkdir -p "/config/plugins/${folder}"
    cp -r "${source}"/* "/config/plugins/${folder}/"
}
install_baked_plugin FileTransformation 5e87cc92-571a-4d8d-8d98-d2d4147f9f90 /jellyfin-file-transformation/plugin
if [ "${WEBTOON_READER_DEV_PLUGIN:-}" != "1" ]; then
    install_baked_plugin WebtoonReader d759c36d-274c-42f6-a32a-b7c482536b4d /jellyfin-webtoon-reader/plugin
fi

if [ ! -f /config/config/database.xml ]; then
    mkdir -p /config/config
    cp /jellyfin-pgsql/database.xml /config/config/database.xml
fi

ConfiguredPluginName="$(xmlstarlet select -t \
    -m '//DatabaseConfigurationOptions/CustomProviderOptions/PluginName' \
    -v . -n /config/config/database.xml)"
if [ "${ConfiguredPluginName}" != "PostgreSQL" ]; then
    echo "database.xml PluginName is '${ConfiguredPluginName}', expected 'PostgreSQL'. Abort."
    exit 2
fi

# Carried over from the 10.11 line: an existing /config/config/database.xml
# from the JPVenson image names the old assembly, which 12.0 cannot load.
# Rewrite it rather than failing on an upgrade of an existing config volume.
xmlstarlet edit -L -u \
    '//DatabaseConfigurationOptions/CustomProviderOptions/PluginAssembly' \
    -v 'Jellyfin.Plugin.Postgresql.dll' /config/config/database.xml

# Checked individually rather than relying on `set -u` further down, which
# would abort with an unhelpful "unbound variable" instead of saying which.
for v in POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD; do
    if [ -z "${!v:-}" ]; then
        echo "\$${v} is unset. Set POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER and POSTGRES_PASSWORD, then restart."
        exit 3
    fi
done

ConnectionString="Password=${POSTGRES_PASSWORD};User ID=${POSTGRES_USER};Host=${POSTGRES_HOST};Port=${POSTGRES_PORT};Database=${POSTGRES_DB}"
if [ -n "${POSTGRES_SSLMODE:-}" ]; then
    ConnectionString="${ConnectionString};SSL Mode=${POSTGRES_SSLMODE}"
fi
if [ -n "${POSTGRES_TRUSTSERVERCERTIFICATE:-}" ]; then
    ConnectionString="${ConnectionString};Trust Server Certificate=${POSTGRES_TRUSTSERVERCERTIFICATE}"
fi

xmlstarlet edit -L -u \
    '//DatabaseConfigurationOptions/CustomProviderOptions/ConnectionString' \
    -v "${ConnectionString}" /config/config/database.xml

exec /jellyfin/jellyfin "$@"
